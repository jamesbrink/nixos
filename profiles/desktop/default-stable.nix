{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    alacritty
    chromium
    vscode
    gimp
    blender
    slack
    gnome3.gnome-remote-desktop
    gnome3.gnome-session
    bitwarden
    fira-code-nerdfont
    nerdfonts
  ];

  services = {
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome3.gnome-session}/bin/gnome-session";
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
