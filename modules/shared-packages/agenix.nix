{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.agenix.nixosModules.default
  ];

  environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.default ];
}
