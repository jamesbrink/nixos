{ pkgs, ... }:

{
  imports = [
    ../../modules/claude-desktop.nix
  ];

  environment.systemPackages = with pkgs; [
    alacritty
    chromium
    vscode
    gimp
    blender
    slack
    gnome-remote-desktop
    gnome-session
    bitwarden
    nerd-fonts.fira-code
  ];

  services = {
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
    };

    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

      displayManager = {
        gdm.enable = true;
      };

      desktopManager.gnome.enable = true;
    };

    printing.enable = true;
  };
}
