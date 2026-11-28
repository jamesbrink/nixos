# Desk mode for hal9000 (docs/factory-desk.md): James stops every piece of
# Quantierra work on his desktop with one switch, and it all comes back after.
#
#   sudo factory-desk on [--now] [--for 4h|90m]   local switch, works with no factory at all
#   sudo factory-desk off
#   factory-desk status
#
# factory-desk-sync runs a pass every 15 s: the effective desk is the local
# flag (/var/lib/factory-desk/local) OR a desk the factory hub set for this
# host (GET workers/v1/desk with a runner's own credential). Desk on: the two
# factory workers stop (a local desk at once, which hands their jobs back; a
# factory desk once the hub shows them idle), idle GitHub runners stop and busy
# ones run at the lowest priority until their job ends (--now / ci "now": at
# once), and remote builds get no new slot (qre-remote.env + a slot hold).
# Desk off undoes exactly what the desk did.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/factory-desk";
  runDir = "/run/factory-desk";
  hubUrl = "https://workers.factory.myquantierra.com:8443/workers/v1/desk";
  runnerNumbers = [
    1
    2
  ];
  factoryUnits = map (n: "factory-runner-hal9000-${toString n}") runnerNumbers;
  # modules/services/qre-ci-runners.nix
  ghUnits = [
    "github-runner-qre-rust-1"
    "github-runner-qre-rust-2"
  ];
  runnerUser = "factory-runner";
  runnerHome = config.users.users.${runnerUser}.home;
  runnerRuntime = "/run/user/${toString config.users.users.${runnerUser}.uid}";
  # The Rust repo's scripts/remote-host.sh (a gate file there: never edited
  # from here) reads only ~/.config/qre-remote.env and takes a build slot with
  # flock on <cache>/.slots/<n>.
  remoteUser = "jamesbrink";
  remoteEnv = "${config.users.users.${remoteUser}.home}/.config/qre-remote.env";
  remoteCache = "/storage-fast/qre-remote";
  remoteSlots = 3;
  holdUnit = "factory-desk-hold.service";
  podman = lib.getExe config.virtualisation.podman.package;

  factory-desk = pkgs.writeShellApplication {
    name = "factory-desk";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gawk
      gnugrep
      jq
      procps
      systemd
      util-linux
    ];
    text = ''
      STATE_DIR=${stateDir}
      RUN_DIR=${runDir}
      HUB_URL=${hubUrl}
      HUB_TTL=600
      HUB_CONNECT_TIMEOUT=5
      HUB_MAX_TIME=10
      SHUTDOWN_MAX_TIME=8
      LOOP_SECS=15
      CGROUP_ROOT=/sys/fs/cgroup
      PROC_ROOT=/proc
      RUNNER_NUMBERS="${lib.concatMapStringsSep " " toString runnerNumbers}"
      FACTORY_UNITS="${lib.concatStringsSep " " factoryUnits}"
      GH_UNITS="${lib.concatStringsSep " " ghUnits}"
      HOLD_UNIT=${holdUnit}
      RUNNER_USER=${runnerUser}
      RUNNER_HOME=${runnerHome}
      RUNNER_RUNTIME=${runnerRuntime}
      RUNNER_CACHE=/mnt/storage-ssd/factory-runner
      PODMAN=${podman}
      REMOTE_USER=${remoteUser}
      REMOTE_ENV=${remoteEnv}
      REMOTE_SLOTS=${toString remoteSlots}
    ''
    + builtins.readFile ./factory-desk.sh;
  };

  # Takes every build slot with a blocking flock, all at once: a free slot at
  # once, a busy one when its build ends (running builds are never killed).
  factory-desk-hold = pkgs.writeShellApplication {
    name = "factory-desk-hold";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    text = ''
      dir=${remoteCache}/.slots
      mkdir -p "$dir"
      for ((i = 1; i <= ${toString remoteSlots}; i++)); do
        (
          exec 8>>"$dir/$i"
          flock 8
          echo "holding remote build slot $i"
          exec sleep infinity
        ) &
      done
      wait
    '';
  };

  bin = "${factory-desk}/bin/factory-desk";
in
{
  environment.systemPackages = [ factory-desk ];

  systemd.tmpfiles.rules = [ "d ${stateDir} 0755 root root -" ];

  systemd.services = {
    factory-desk-sync = {
      description = "Desk mode: apply the local switch or the factory's desk every 15 s";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      serviceConfig = {
        ExecStart = "${bin} loop";
        Restart = "always";
        RestartSec = 5;
      };
    };

    factory-desk-hold = {
      description = "Desk mode: hold the remote build slots so no new remote build starts";
      after = [ "zfs-mount.service" ];
      unitConfig.ConditionPathIsMountPoint = "/storage-fast";
      # A restart would let go of the slots for a moment.
      restartIfChanged = false;
      serviceConfig = {
        User = remoteUser;
        ExecStart = lib.getExe factory-desk-hold;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    "factory-desk-gh-drain@" = {
      description = "Desk mode: stop %i once its job ends";
      serviceConfig.ExecStart = "${bin} gh-drain %i";
    };

    # Ordered after the workers and the network, so at shutdown it stops
    # before them: the hub hears "desk on, why shutdown" first and counts the
    # workers' stops as planned. The next boot's sync lifts that desk.
    factory-desk-shutdown = {
      description = "Desk mode: tell the factory before the workers stop at shutdown";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = map (u: "${u}.service") factoryUnits ++ [
        "network-online.target"
        "tailscaled.service"
      ];
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${bin} shutdown-hook";
        # two hub calls at most (a 401 tries the other runner's credential), 8 s each
        TimeoutStopSec = 25;
      };
    };
  }
  # While the desk holds a unit, neither Restart= nor a switch nor a boot with
  # the local switch on starts it.
  // lib.genAttrs (factoryUnits ++ ghUnits) (unit: {
    unitConfig.ConditionPathExists = [
      "!${stateDir}/local"
      "!${runDir}/stopped/${unit}"
    ];
  });
}
