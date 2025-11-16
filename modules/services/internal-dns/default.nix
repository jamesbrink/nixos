{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.internal-dns;

  ensureTrailingDot = value: if lib.hasSuffix "." value then value else "${value}.";

  formatEmail = email: ensureTrailingDot (lib.replaceStrings [ "@" ] [ "." ] email);

  formattedPrimaryNs =
    if cfg.primaryNameserver != null then
      ensureTrailingDot cfg.primaryNameserver
    else
      ensureTrailingDot "${config.networking.hostName}.${cfg.domain}";

  formattedAdminEmail =
    if cfg.adminEmail != null then formatEmail cfg.adminEmail else formatEmail "admin@${cfg.domain}";

  zoneRecords = lib.concatMapStrings (
    record:
    let
      values = if builtins.isList record.value then record.value else [ record.value ];
      ttlValue = if record.ttl != null then record.ttl else cfg.ttl;
      ttl = toString ttlValue;
    in
    lib.concatMapStrings (value: "${record.name} ${ttl} IN ${record.type} ${value}\n") values
  ) cfg.records;

  zoneFile = pkgs.writeText "${cfg.domain}.zone" ''
    $TTL ${toString cfg.ttl}
    @ IN SOA ${formattedPrimaryNs} ${formattedAdminEmail} (
      ${cfg.serial}
      ${toString cfg.refresh}
      ${toString cfg.retry}
      ${toString cfg.expire}
      ${toString cfg.minimum}
    )

    @ IN NS ${formattedPrimaryNs}

    ${zoneRecords}
  '';

  allowedClients = cfg.allowedClients ++ [ "127.0.0.1/32" ];
in
{
  options.services.internal-dns = {
    enable = lib.mkEnableOption "authoritative internal DNS via BIND";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "home.urandom.io";
      description = "DNS zone served by the internal resolver.";
    };

    ttl = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Default TTL for records in the zone.";
    };

    serial = lib.mkOption {
      type = lib.types.str;
      default = "2025111601";
      description = "SOA serial number for the zone. Bump when records change.";
    };

    refresh = lib.mkOption {
      type = lib.types.int;
      default = 7200;
      description = "SOA refresh interval.";
    };

    retry = lib.mkOption {
      type = lib.types.int;
      default = 900;
      description = "SOA retry interval.";
    };

    expire = lib.mkOption {
      type = lib.types.int;
      default = 1209600;
      description = "SOA expire time.";
    };

    minimum = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "SOA minimum TTL.";
    };

    primaryNameserver = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Primary nameserver FQDN used in the SOA record.";
    };

    adminEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Administrative contact email (e.g. admin@example.com).";
    };

    records = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Relative record name (use @ for zone apex).";
              };

              type = lib.mkOption {
                type = lib.types.str;
                description = "DNS record type (A, CNAME, etc.).";
              };

              value = lib.mkOption {
                type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
                description = "Record value or list of values.";
              };

              ttl = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Record-specific TTL (defaults to zone TTL).";
              };
            };
          }
        )
      );
      default = [ ];
      description = "Records served from the internal zone file.";
    };

    forwarders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      description = "Upstream DNS servers for recursive lookups.";
    };

    allowedClients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1/32" ];
      description = "CIDRs allowed to perform recursive lookups.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses BIND should listen on.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.bind = {
      enable = true;
      package = pkgs.bind;
      listenOn = cfg.listenAddresses;
      listenOnIpv6 = [ ];
      cacheNetworks = allowedClients;
      forwarders = cfg.forwarders;
      extraOptions = ''
        recursion yes;
        allow-recursion {
          ${lib.concatMapStrings (net: "${net};\n") allowedClients}
        };
        allow-transfer { none; };
        dnssec-validation no;
      '';
      extraConfig = ''
        # Forward ACME challenge queries to public DNS
        zone "_acme-challenge.${cfg.domain}" {
          type forward;
          forward only;
          forwarders { 1.1.1.1; 8.8.8.8; };
        };
      '';
      zones = {
        "${cfg.domain}" = {
          master = true;
          file = zoneFile;
          allowQuery = allowedClients;
        };
      };
    };

    networking.firewall = {
      allowedUDPPorts = lib.mkAfter [ 53 ];
      allowedTCPPorts = lib.mkAfter [ 53 ];
    };
  };
}
