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

  # RustDesk for headless remote desktop access (uses dummy X driver)
  services.rustdesk-client = {
    enable = true;
    headless = true;
  };

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
    bitwarden-desktop
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

  # PolicyKit rules to allow LightDM to access accounts-daemon
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.DisplayManager.AccountsService.ReadAny" ||
          action.id == "org.freedesktop.DisplayManager.AccountsService.WriteAny") {
        return polkit.Result.YES;
      }
    });
  '';

  services = {
    # Accounts daemon required for LightDM user management
    accounts-daemon.enable = true;

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

      # LightDM display manager with X11 (better for XFCE)
      displayManager = {
        lightdm.enable = true;
      };

      # XFCE desktop environment
      desktopManager.xfce.enable = true;
    };

    printing.enable = true;
  };
}
