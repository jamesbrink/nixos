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
  localHosts = {
    # Network infrastructure
    "10.70.100.1" = [
      "router"
      "router.home.urandom.io"
    ];
    "10.70.100.200" = [
      "TL-SG108E"
      "switch"
      "switch.home.urandom.io"
    ];

    # Main servers
    "10.70.100.2" = [
      "corbelan"
      "corbelan.home.urandom.io"
    ];
    "10.70.100.206" = [
      "hal9000"
      "hal9000.home.urandom.io"
    ];
    "10.70.100.205" = [
      "alienware"
      "alienware.home.urandom.io"
    ];
    "10.70.100.207" = [
      "darkstarmk6mod1"
      "darkstarmk6mod1.home.urandom.io"
    ];

    # N100 cluster nodes
    "10.70.100.201" = [
      "n100-01"
      "n100-01.home.urandom.io"
    ];
    "10.70.100.202" = [
      "n100-02"
      "n100-02.home.urandom.io"
    ];
    "10.70.100.203" = [
      "n100-03"
      "n100-03.home.urandom.io"
    ];
    "10.70.100.204" = [
      "n100-04"
      "n100-04.home.urandom.io"
    ];

    # Other hosts
    "10.70.100.196" = [
      "vmware"
      "vmware.home.urandom.io"
    ];
    "10.70.100.192" = [
      "server02"
      "server02.home.urandom.io"
    ];
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
