# Software KVM (keyboard + mouse sharing) between halcyon (Mac) and hal9000 (Hyprland).
#
# Uses lan-mouse v0.11.0 from the upstream flake (wired in flake.nix). nixpkgs still
# ships 0.10.0, which predates the wlroots modifier-key emulation fix (PR #238) required
# for Ctrl/Shift/Alt/Super to register on the Hyprland receiver.
#
# The two machines reach each other only over Tailscale — their wired LAN subnets are
# isolated (halcyon 192.168.0.x, hal9000 192.168.1.x) — so peers are addressed by their
# stable Tailscale IPs. hal9000 sits to the LEFT of halcyon on the desk.
#
# This module is imported on every desktop host but self-gates to halcyon/hal9000, so it
# is a no-op everywhere else. The upstream `programs.lan-mouse` module is imported at the
# call site (the user files) — importing it here via `inputs` would reference a module arg
# inside `imports` and trigger infinite recursion.
{
  lib,
  osConfig ? null,
  ...
}:
let
  hostName = osConfig.networking.hostName or "";
  isHalcyon = hostName == "halcyon";
  isHal9000 = hostName == "hal9000";

  # Stable Tailscale (MagicDNS) addresses.
  tailscaleIp = {
    halcyon = "100.80.133.72";
    hal9000 = "100.123.198.98";
  };
in
{
  programs.lan-mouse = lib.mkIf (isHalcyon || isHal9000) {
    enable = true;
    settings = {
      port = 4242;

      # Tap the whole home row (A+S+D+F) together to release capture back to this machine.
      release_bind = [
        "KeyA"
        "KeyS"
        "KeyD"
        "KeyF"
      ];

      # TLS fingerprints authorized for INCOMING connections (SHA-256 of the peer's
      # lan-mouse cert, ~/.config/lan-mouse/lan-mouse.pem, captured on first run). Each
      # host trusts the OTHER host's cert. Managed declaratively because the config.toml
      # is a read-only Nix symlink, so lan-mouse's runtime "authorize" can't persist.
      authorized_fingerprints =
        if isHalcyon then
          {
            "49:c0:cc:b0:db:36:48:60:0c:31:a1:d3:f4:91:99:88:3e:2b:ce:17:0d:d8:98:50:eb:11:96:d4:c5:bd:94:74" =
              "hal9000";
          }
        else
          {
            "cb:63:2e:ed:89:a4:83:0e:b9:e1:51:83:59:f0:51:71:1a:38:b6:4b:8e:24:da:6a:54:19:40:b7:5e:17:f6:32" =
              "halcyon";
          };

      # The peer machine and which screen edge it lives on.
      clients =
        if isHalcyon then
          [
            {
              # hal9000 is to the LEFT of halcyon: shove the cursor off the left edge.
              position = "left";
              hostname = "hal9000";
              ips = [ tailscaleIp.hal9000 ];
              activate_on_startup = true;
            }
          ]
        else
          [
            {
              # halcyon is to the RIGHT of hal9000.
              position = "right";
              hostname = "halcyon";
              ips = [ tailscaleIp.halcyon ];
              activate_on_startup = true;
            }
          ];
    };
  };

  # Guarantee the daemon comes up with the graphical session on hal9000. The upstream
  # module only binds WantedBy=hyprland-session.target when the HM hyprland systemd
  # integration is enabled; this is a belt-and-suspenders fallback (no-op elsewhere).
  systemd.user.services.lan-mouse.Install.WantedBy = lib.mkIf isHal9000 [
    "graphical-session.target"
  ];
}
