# Keep the local Discord client authenticated without a key in the Nix store.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mold;
  runtimeDirectory = "mold-discord-auth";
  environmentFile = "/run/${runtimeDirectory}/env";
in
{
  config = lib.mkIf (cfg.enable && cfg.discord.enable && cfg.apiKeyFile != null) {
    services.mold.discord.moldHost = lib.mkDefault "http://127.0.0.1:${toString cfg.port}";
    systemd.services.mold-discord.serviceConfig = {
      RuntimeDirectory = runtimeDirectory;
      RuntimeDirectoryMode = "0700";
      # Mold's HTTP client accepts the value, while the server accepts @file.
      # Read the same operator key as the mold user immediately before launch.
      ExecStartPre = [
        (pkgs.writeShellScript "mold-discord-auth-env" ''
          set -euo pipefail
          umask 077
          key="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (toString cfg.apiKeyFile)})"
          [[ "$key" =~ ^[A-Za-z0-9_]{32,}$ ]] || exit 1
          printf 'MOLD_API_KEY=%s\n' "$key" > ${environmentFile}
          ${pkgs.coreutils}/bin/chmod 0600 ${environmentFile}
        '')
      ];
      EnvironmentFile = lib.mkForce [
        cfg.discord.tokenFile
        "-${environmentFile}"
      ];
    };
  };
}
