# Local network hosts configuration for Linux
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # Define all local network hosts based on your Terraform DHCP configuration
  # Removed .home.urandom.io FQDNs to prevent wildcard DNS (*.home.urandom.io) from intercepting external domains
  localHosts = {
    # Network infrastructure
    "10.70.100.1" = [ "router" ];
    "10.70.100.200" = [
      "TL-SG108E"
      "switch"
    ];

    # Main servers
    "10.70.100.2" = [ "corbelan" ];
    "10.70.100.206" = [ "hal9000" ];
    "10.70.100.205" = [ "alienware" ];
    "10.70.100.208" = [ "sevastopol" ];

    # N100 cluster nodes
    "10.70.100.201" = [ "n100-01" ];
    "10.70.100.202" = [ "n100-02" ];
    "10.70.100.203" = [ "n100-03" ];
    "10.70.100.204" = [ "n100-04" ];

    # Other hosts
    "10.70.100.196" = [ "vmware" ];
    "100.105.134.43" = [ "plato" ];
    "10.70.100.192" = [ "server02" ];
  };

  # Convert the localHosts attribute set to hosts file entries
  hostsEntries = lib.mapAttrsToList (ip: names: "${ip} ${lib.concatStringsSep " " names}") localHosts;

in
{
  options.networking.localHosts = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable local network hosts entries";
    };
  };

  config = mkIf (config.networking.localHosts.enable && !pkgs.stdenv.isDarwin) {
    # Linux: Use networking.extraHosts
    networking.extraHosts = lib.concatStringsSep "\n" hostsEntries;
  };
}
