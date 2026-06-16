# WiFi support via iwd, designed to coexist with systemd-networkd.
#
# iwd manages only the wireless *link* (scanning, auth, roaming); systemd-networkd
# keeps doing IP/DHCP — the same division of labor this fleet uses for wired links.
# This avoids the interface tug-of-war NetworkManager would cause on hosts that run
# a libvirt/incus/k3s/docker bridge stack (e.g. hal9000's br0).
#
# Tools provided:
#   - iwctl  (CLI, ships with iwd)        : iwctl station <iface> scan / get-networks / connect <SSID>
#   - iwgtk  (GUI, GTK tray + window)     : run `iwgtk` for a window, `iwgtk -i` for a tray indicator
#   - iw     (low-level diagnostics)      : iw dev, iw <iface> link, iw <iface> scan
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.wifi;
in
{
  options.local.wifi = {
    enable = lib.mkEnableOption "WiFi via iwd with systemd-networkd integration";

    routeMetric = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = ''
        DHCP route metric for the WiFi link. Higher = less preferred. The default
        (2048) sits above networkd's wired default (1024) so a wired connection
        always wins when both are up, making WiFi a fallback. Lower it below 1024
        to prefer WiFi.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Backend: iwd owns the radio link only. EnableNetworkConfiguration stays at
    # its default (false), so iwd leaves DHCP/addressing to systemd-networkd below.
    networking.wireless.iwd = {
      enable = true;
      settings = {
        General.EnableNetworkConfiguration = false;
        Settings.AutoConnect = true;
      };
    };

    # Let networkd do DHCP on the wireless link once iwd brings it up. Match by
    # device *type*, not name — wireless interface names flip between predictable
    # (wlo1) and classic (wlan0) depending on udev/iwd, so a name match is brittle.
    systemd.network.networks."30-wireless" = {
      matchConfig.Type = "wlan";
      networkConfig.DHCP = "ipv4";
      dhcpV4Config.RouteMetric = cfg.routeMetric;
      # Don't block `systemd-networkd-wait-online` on WiFi — it's a fallback link.
      linkConfig.RequiredForOnline = "no";
    };

    environment.systemPackages = with pkgs; [
      iwgtk # GUI: GTK wifi manager + tray indicator
      iw # CLI: low-level wireless diagnostics
    ];
  };
}
