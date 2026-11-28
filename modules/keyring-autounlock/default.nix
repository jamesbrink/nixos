# Unlock the gnome-keyring login collection without a prompt.
#
# With display-manager autologin, PAM never sees a password, so the login
# keyring starts locked and every libsecret client (Chrome's cookie key,
# Signal, ...) blocks on an unlock prompt. If gnome-keyring is restarted
# without a display (a remote deploy did this on 2026-11-19), the prompt fails
# and the daemon never prompts again: Chrome then spins on every page.
#
# This user service reads the keyring password from an agenix secret and
# unlocks the running daemon over D-Bus at login, then re-checks on a timer so
# a restarted (re-locked) daemon is unlocked again within minutes.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.keyringAutoUnlock;
  unlock = pkgs.writers.writePython3Bin "keyring-autounlock" {
    libraries = [ pkgs.python3Packages.jeepney ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./unlock.py);
in
{
  options.local.keyringAutoUnlock = {
    enable = lib.mkEnableOption "prompt-less gnome-keyring login unlock from a password file";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose login keyring is unlocked.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "File holding the login keyring password, readable only by `user` (e.g. an agenix secret).";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to re-check and unlock a re-locked keyring.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ unlock ];

    systemd.user.services.keyring-autounlock = {
      description = "Unlock the gnome-keyring login collection";
      unitConfig.ConditionUser = cfg.user;
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe unlock} ${cfg.passwordFile}";
      };
    };

    systemd.user.timers.keyring-autounlock = {
      description = "Re-unlock the gnome-keyring login collection if it was re-locked";
      unitConfig.ConditionUser = cfg.user;
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnActiveSec = "1min";
        OnUnitActiveSec = cfg.interval;
      };
    };
  };
}
