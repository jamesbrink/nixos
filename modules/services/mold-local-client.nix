# Privileged local CLI convenience; no secret or new sudo authorization in Nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mold;
  client = pkgs.writeShellScriptBin "mold-local" ''
    set -euo pipefail
    export MOLD_HOST="http://127.0.0.1:${toString cfg.port}"
    export MOLD_CONNECTION_MODE=secure
    export MOLD_HOME=${lib.escapeShellArg cfg.homeDir}
    MOLD_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (toString cfg.apiKeyFile)})"
    [[ "$MOLD_API_KEY" =~ ^[A-Za-z0-9_]{32,}$ ]] || exit 1
    export MOLD_API_KEY
    exec ${cfg.package}/bin/mold "$@"
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.apiKeyFile != null) {
    environment.systemPackages = [ client ];
  };
}
