# WiFi via NetworkManager (iwd backend), scoped to wireless devices only.
#
# For desktops whose shell drives Wi-Fi through NetworkManager (Omarchy's
# network panel). Wired links, bridges and VPN interfaces stay unmanaged so
# systemd-networkd keeps owning them; Wi-Fi remains a lower-priority fallback.
{
  config,
  lib,
  ...
}:
let
  cfg = config.local.wifiNetworkManager;
in
{
  options.local.wifiNetworkManager = {
    enable = lib.mkEnableOption "WiFi via NetworkManager (iwd backend), wireless devices only";
    routeMetric = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = ''
        Route metric for Wi-Fi connections. Higher = less preferred. The default
        sits above networkd's wired default (1024) so wired always wins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
      # Everything except Wi-Fi stays with systemd-networkd.
      unmanaged = [ "except:type:wifi" ];
      dns = lib.mkIf config.services.resolved.enable "systemd-resolved";
      settings."connection-wifi-metric" = {
        match-device = "type:wifi";
        "ipv4.route-metric" = cfg.routeMetric;
        "ipv6.route-metric" = cfg.routeMetric;
      };
    };

    # networkd-wait-online already gates boot on the wired link.
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
