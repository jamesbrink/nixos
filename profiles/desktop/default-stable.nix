{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    alacritty
    bitwarden
    blender
    chromium
    fira-code-nerdfont
    gimp
    gnome3.gnome-remote-desktop
    gnome3.gnome-session
    nerdfonts
    # rustdesk
    rustdesk-flutter
    slack
    vscode
  ];

  services = {
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome3.gnome-session}/bin/gnome-session";
      openFirewall = true;
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
