#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
module="$repo/modules/services/mold-local-client.nix"
# The service credential must be read only at runtime and never reach argv.
[[ -f "$module" ]]
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
chmod 0700 "$fixture"
printf '%s' 'test_operator_credential_0123456789' > "$fixture/key"
chmod 0600 "$fixture/key"
cat > "$fixture/test.nix" <<'NIX'
{ nixpkgs, module, keyPath }:
let
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  mock = pkgs.writeShellScriptBin "mold" ''
    set -euo pipefail
    [[ "$MOLD_API_KEY" == test_operator_credential_0123456789 ]]
    [[ "$MOLD_HOST" == http://127.0.0.1:7680 ]]
    [[ "$MOLD_CONNECTION_MODE" == secure ]]
    [[ "$MOLD_HOME" == /tmp/mold-local-client-contract ]]
    [[ "$#" == 2 && "$1" == server && "$2" == status ]]
    printf 'private runtime credential and unchanged arguments: pass\n'
  '';
  result = import module {
    inherit pkgs;
    lib = pkgs.lib;
    config.services.mold = {
      enable = true;
      apiKeyFile = keyPath;
      package = mock;
      homeDir = "/tmp/mold-local-client-contract";
      port = 7680;
    };
  };
in assert result.config.condition; builtins.head result.config.content.environment.systemPackages
NIX
nixpkgs=$(nix flake metadata --json "$repo" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("github:NixOS/nixpkgs/"+d["locks"]["nodes"]["nixpkgs"]["locked"]["rev"])')
wrapper=$(nix build --impure --no-link --print-out-paths --file "$fixture/test.nix" --arg nixpkgs "(builtins.getFlake \"$nixpkgs\").outPath" --arg module "$module" --argstr keyPath "$fixture/key")
"$wrapper/bin/mold-local" server status
rm "$fixture/key"
if "$wrapper/bin/mold-local" server status >/dev/null 2>&1; then
  echo 'missing private key must fail' >&2
  exit 1
fi
