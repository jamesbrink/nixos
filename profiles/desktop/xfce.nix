{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # ../../modules/claude-desktop.nix  # TODO: Fix hash mismatch upstream
    ../../modules/ssh-keys.nix
    ../../modules/nfs-mounts.nix
    ../../modules/aws-root-config.nix
    ../../modules/rustdesk-client.nix
    ../../users/root.nix
  ];

  # Enable zsh as default shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Set zsh as default shell
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    # Core desktop applications
    alacritty
    chromium
    bitwarden
    vscode

    # Media applications
    gimp
    inkscape-with-extensions
    vlc

    # XFCE applications and utilities
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.xfce4-terminal
    xfce.xfce4-taskmanager
    xfce.xfce4-screenshooter
    xfce.xfce4-clipman-plugin
    xfce.xfce4-pulseaudio-plugin

    # Remote desktop (RustDesk installed via rustdesk-client module)
    rustdesk-flutter

    # Fonts
    nerd-fonts.fira-code
  ];

  services = {
    # XRDP for Windows Remote Desktop Protocol access
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/startxfce4";
      openFirewall = true;
    };

    # X11 server configuration
    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

      # GDM display manager with X11 (required for RustDesk headless support)
      displayManager = {
        gdm.enable = true;
        gdm.wayland = false;
      };

      # XFCE desktop environment
      desktopManager.xfce.enable = true;
    };

    printing.enable = true;
  };
}
