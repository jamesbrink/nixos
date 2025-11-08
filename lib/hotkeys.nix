{ pkgs }:

let
  hotkeysYaml = ../config/hotkeys.yaml;
  hotkeysJson = pkgs.runCommand "hotkeys.json" { } ''
    ${pkgs.remarshal}/bin/remarshal \
      -if yaml \
      -of json \
      -i ${hotkeysYaml} \
      -o $out
  '';
  hotkeysData = builtins.fromJSON (builtins.readFile hotkeysJson);
in
{
  data = hotkeysData;
  jsonPath = hotkeysJson;
}
