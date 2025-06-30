# This module installs the agenix CLI tools
# The agenix module itself is imported at the flake level
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    agenix
    age
  ];
}
