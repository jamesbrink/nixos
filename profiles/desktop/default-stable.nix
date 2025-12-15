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
    # Claude Desktop application
    # TODO: Re-enable when upstream hash is fixed
    # inputs.claude-desktop.packages.${pkgs.system}.claude-desktop
    alacritty
    bitwarden-desktop
    blender
    chromium
    fusuma
    gimp
    gnome-remote-desktop
    gnome-session
    gnome-tweaks
    inkscape-with-extensions
    libinput
    libinput-gestures
    nerd-fonts.fira-code
    rustdesk
    rustdesk-flutter
    slack
    vlc
    vscode
  ];

  services = {
    xrdp = {
      enable = true;
      defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session";
      openFirewall = true;
    };

    libinput.enable = true;
    touchegg.enable = true;

    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

      displayManager = {
        gdm.enable = true;
      };

      inputClassSections = [
        ''
          Section "InputClass"
            Identifier "Magic Trackpad"
            MatchDriver "libinput"
            MatchProduct "Magic Trackpad"
            Option "NaturalScrolling" "true"
            Option "Tapping" "true"
            Option "ClickMethod" "clickfinger"
            Option "ScrollMethod" "twofinger"
            Option "HorizontalScrolling" "true"
            Option "DisableWhileTyping" "false"
          EndSection
        ''
      ];
      desktopManager.gnome.enable = true;
    };
    printing.enable = true;
  };

  boot.kernelParams = [ "psmouse.synaptics_intertouch=0" ];

}
