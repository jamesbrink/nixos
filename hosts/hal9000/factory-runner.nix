{
  config,
  lib,
  ...
}:
let
  user = "factory-runner";
  uid = 3100;
  runtime = "/run/user/${toString uid}";
  manager = "user@${toString uid}.service";
  home = "/var/lib/${user}";
  cache = "${home}/cache";
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
    "d ${cache} 0700 ${user} ${user} -"
    "d ${envDir} 0700 root root -"
  ];

  systemd.services = lib.genAttrs units (unit: {
    description = "Factory container worker ${lib.removePrefix "factory-runner-" unit}";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      manager
    ];
    after = [
      "network-online.target"
      manager
    ];
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
  });
}
