# Omarchy v4 desktop via nixarchy, offered as its own "Omarchy" session next to
# the existing Hyprland session. Omarchy's Quickshell shell brings the bar,
# menus, Wi-Fi/Bluetooth/audio/display panels, agent integration and theming.
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.nixarchy.nixosModules.nixarchy ];

  programs.nixarchy = {
    enable = true;
    user = "jamesbrink";
    defaultAgent = "claude";
    # Keep our SDDM (autologin + theme) instead of nixarchy's greeter.
    displayManager = false;
    # Keep the existing boot (no Plymouth splash).
    bootSplash = "off";
  };

  # Autologin straight into the Omarchy session.
  services.displayManager.defaultSession = lib.mkForce "omarchy";

  # nixarchy defaults to linuxPackages_latest; stay on the release kernel so
  # ZFS and the NVIDIA driver keep matching what nixpkgs tests together.
  boot.kernelPackages = pkgs.linuxPackages;

  # Keep the Hyprland the rest of the system already uses (0.55, from nixpkgs).
  programs.hyprland.package = lib.mkForce pkgs.hyprland;
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  home-manager.users.jamesbrink = {
    imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
    programs.nixarchy.enable = true;
    # nixi (guided tour) pulls codex-acp, which fails to link on 26.05.
    services.nixi.enable = false;

    # omarchy-shell replaces the legacy desktop shell from
    # modules/home-manager/hyprland: bar, notifications, OSD, idle/lock.
    programs.waybar.enable = lib.mkForce false;
    services.mako.enable = lib.mkForce false;
    services.hypridle.enable = lib.mkForce false;
    # themectl writes Omarchy-v3 themes into ~/.config/omarchy/themes, which
    # Omarchy v4 reads as user-installed themes. It stays on Darwin.
    programs.themectl.enable = lib.mkForce false;

    # Hide tray apps the shell replaces with its Wi-Fi, Bluetooth and polkit panels.
    xdg.configFile =
      lib.genAttrs
        (map (n: "autostart/${n}.desktop") [
          "blueman"
          "iwgtk-indicator"
          "nm-applet"
          "polkit-gnome-authentication-agent-1"
        ])
        (_: {
          text = "[Desktop Entry]\nType=Application\nHidden=true\n";
        });
  };
}
