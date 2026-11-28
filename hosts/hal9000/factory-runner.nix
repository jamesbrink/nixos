{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = "factory-runner";
  uid = 3100;
  runtime = "/run/user/${toString uid}";
  manager = "user@${toString uid}.service";
  home = "/var/lib/${user}";
  # The shared card cache (cargo targets per card, tens of GB each) lives on the
  # storage-ssd pool, off the root disk James's desktop shares. The dataset is
  # made by hand, never by activation (see storage-ssd-import in default.nix):
  #   zfs create -o quota=500G storage-ssd/factory-runner
  #   chown factory-runner:factory-runner /mnt/storage-ssd/factory-runner
  #   chmod 0700 /mnt/storage-ssd/factory-runner
  # The Podman store (image ~11 GB, container layers) stays in ${home}.
  cache = "/mnt/storage-ssd/factory-runner";
  ssdImport = "storage-ssd-import.service";
  # Daily prune of the card cache and the remote-test build cache until the
  # factory runner evicts on its own. Card dirs and targets idle longer than
  # maxIdleHours go; over budgetGB the least recently used go first, never one
  # idle under minIdleHours or one a process is working in.
  prune = {
    budgetGB = 350;
    maxIdleHours = 48;
    minIdleHours = 6;
    remoteCache = "/storage-fast/qre-remote";
  };
  envDir = "/etc/${user}";
  podman = lib.getExe config.virtualisation.podman.package;
  image = "localhost/factory-runner:current";
  devdb = "100.108.165.3";
  units = [
    "factory-runner-hal9000-1"
    "factory-runner-hal9000-2"
  ];
in
{
  users.groups.${user} = { };
  users.users.${user} = {
    inherit uid home;
    group = user;
    isSystemUser = true;
    createHome = true;
    linger = true;
    subUidRanges = [
      {
        startUid = 300000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 300000;
        count = 65536;
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${envDir} 0700 root root -"
  ];

  systemd.services =
    lib.genAttrs units (unit: {
      description = "Factory container worker ${lib.removePrefix "factory-runner-" unit}";
      # storage-ssd is a USB disk imported after boot (or on hotplug): start with
      # it, stop before it is exported, never run on the root disk without it.
      wantedBy = [
        "multi-user.target"
        ssdImport
      ];
      bindsTo = [ ssdImport ];
      wants = [
        "network-online.target"
        manager
      ];
      after = [
        "network-online.target"
        manager
        ssdImport
      ];
      unitConfig.AssertPathIsMountPoint = cache;
      restartIfChanged = false;
      environment = {
        HOME = home;
        XDG_RUNTIME_DIR = runtime;
        DBUS_SESSION_BUS_ADDRESS = "unix:path=${runtime}/bus";
      };
      serviceConfig = {
        User = user;
        Group = user;
        Delegate = true;
        EnvironmentFile = "-${envDir}/${unit}.env";
        ExecCondition = "${podman} image exists ${image}";
        ExecStart = lib.concatStringsSep " " [
          "${podman} run --rm --replace --pull=never --cap-add NET_ADMIN --name ${unit}"
          # Leave about 34 GiB and 20 CPU equivalents outside the two overflow workers.
          "--cpus 6 --memory 14g --memory-swap 14g --pids-limit 8192 --shm-size 8g --stop-timeout 100"
          "--dns 1.1.1.1 --add-host devdb.factory.internal:${devdb}"
          "--volume ${unit}-state:/var/lib/factory-runner --volume ${cache}:/cache"
          "--env FACTORY_RUNNER_NAME=${lib.removePrefix "factory-runner-" unit} --env FACTORY_REGISTRATION_TOKEN"
          "--env FACTORY_URL=https://workers.factory.myquantierra.com:8443"
          "--env FACTORY_RUNNER_EGRESS=filter --env FACTORY_RUNNER_EGRESS_ALLOW=${devdb}:5432"
          image
        ];
        ExecStop = "${podman} stop -t 100 --ignore ${unit}";
        KillMode = "mixed";
        Nice = 10;
        Restart = "always";
        RestartSec = 10;
        # A hub-requested drain (7) is clean. Bad setup (2) or credentials (3) need operator action.
        RestartPreventExitStatus = "2 3 7";
        SuccessExitStatus = "7";
        TimeoutStopSec = 120;
      };
    })
    // {
      factory-runner-cache-prune = {
        description = "Prune idle factory card caches and remote-test build targets";
        after = [ ssdImport ];
        unitConfig.ConditionPathIsMountPoint = cache;
        serviceConfig = {
          Type = "oneshot";
          Nice = 19;
          IOSchedulingClass = "idle";
        };
        script = lib.getExe (
          pkgs.writeShellApplication {
            name = "factory-runner-cache-prune";
            runtimeInputs = with pkgs; [
              coreutils
              findutils
              gawk
              gnugrep
              gnused
              util-linux
            ];
            text = ''
              cache=${cache}
              remote=${prune.remoteCache}
              budget_gb=${toString prune.budgetGB}
              max_min=$((${toString prune.maxIdleHours} * 60))
              min_min=$((${toString prune.minIdleHours} * 60))
              now=$(date +%s)

              # Minutes since a dir was last touched: its stamp file ($2) if any,
              # else its newest entry near the top.
              idle_min() {
                local newest
                if [[ -n ''${2:-} && -e $2 ]]; then
                  newest=$(stat -c %Y "$2")
                else
                  newest=$(find "$1" -maxdepth 3 -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
                fi
                echo $(((now - ''${newest%.*}) / 60))
              }
              used_gb() { df -Pk "$1" | awk 'NR == 2 { print int($3 / 1048576) }'; }

              # Card dirs some process works in (a running job's cwd). Inside a
              # worker container the cache is /cache, so map that back too.
              busy=$(find /proc -mindepth 2 -maxdepth 2 -name cwd -printf '%l\n' 2>/dev/null |
                sed -nE "s#^(/cache|$cache)/cards/([^/]+/[^/]+).*#$cache/cards/\2#p" | sort -u || true)

              cards() {
                local d
                for d in "$cache"/cards/*/*/; do
                  d=''${d%/}
                  if grep -qxF "$d" <<<"$busy"; then continue; fi
                  echo "$(idle_min "$d") $d"
                done | sort -rn
              }
              drop_card() {
                echo "pruning card cache $2 (idle $1 min, $3)"
                rm -rf --one-file-system "$2"
              }

              shopt -s nullglob
              while read -r idle dir; do
                if ((idle >= max_min)); then drop_card "$idle" "$dir" "older than ${toString prune.maxIdleHours} h"; fi
              done < <(cards)
              while read -r idle dir; do
                if (($(used_gb "$cache") <= budget_gb)); then break; fi
                if ((idle >= min_min)); then drop_card "$idle" "$dir" "over $budget_gb GB"; fi
              done < <(cards)

              # remote-test.sh targets (the Rust repo's scripts/remote-prune.sh
              # layout): only ours, never main, under the build's own lock.
              if [[ -d $remote/target ]]; then
                for dir in "$remote"/target/*/; do
                  dir=''${dir%/}
                  if [[ ''${dir##*/} == main || ! -e $dir/.qre-target ]]; then continue; fi
                  idle=$(idle_min "$dir" "$dir.used")
                  ((idle >= max_min)) || continue
                  exec 6>"$dir.lock"
                  if flock -n -x 6; then
                    echo "pruning remote target $dir (idle $idle min)"
                    rm -rf --one-file-system "$dir" "$dir.used" "$dir.lock"
                  fi
                  exec 6>&-
                done
              fi

              df -h "$cache" "$remote" | sort -u
            '';
          }
        );
      };
    };

  systemd.timers.factory-runner-cache-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
