# Weekly pruning of unused container resources older than N days.
#
# Covers Docker, system (root) Podman and every user's rootless Podman store.
# `--all` matters: without it only dangling images go, so tagged images that no
# container uses pile up forever (hal9000 reached 99% disk that way).
# Running containers, the images they use, and volumes are never touched.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.containerPrune;
  flags = [
    "--all"
    "--filter"
    "until=${toString (cfg.olderThanDays * 24)}h"
  ];
in
{
  options.local.containerPrune = {
    enable = lib.mkEnableOption "weekly pruning of unused containers, images and build cache";
    olderThanDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Only prune stopped containers, images and build cache unused for this many days.";
    };
    dates = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd OnCalendar expression for the prune timers.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
      enable = true;
      inherit (cfg) dates;
      inherit flags;
    };

    virtualisation.podman.autoPrune = lib.mkIf config.virtualisation.podman.enable {
      enable = true;
      inherit (cfg) dates;
      inherit flags;
    };

    # Rootless Podman keeps a separate store per user (~/.local/share/containers);
    # the system timer above never sees it.
    systemd.user.services.podman-prune = lib.mkIf config.virtualisation.podman.enable {
      description = "Prune unused rootless Podman resources";
      unitConfig.ConditionUser = "!@system";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe config.virtualisation.podman.package} system prune --force ${lib.escapeShellArgs flags}";
      };
    };
    systemd.user.timers.podman-prune = lib.mkIf config.virtualisation.podman.enable {
      description = "Weekly rootless Podman prune";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
