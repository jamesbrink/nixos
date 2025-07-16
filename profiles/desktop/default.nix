{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/claude-desktop.nix
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/local-hosts.nix
  ];

  environment.systemPackages = with pkgs; [
    # Claude Desktop application
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop
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
    # Networking
    tailscale
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
