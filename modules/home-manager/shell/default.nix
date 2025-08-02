{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./zsh.nix
    ./bash.nix
    ./starship.nix
    ./tmux.nix
    ../editor/neovim.nix
    ../cli-tools.nix
  ];

  # Additional shell-agnostic configurations
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";

    CLAUDE_BASH_COMMAND_TIMEOUT = "150000";
    CLAUDE_BASH_COMMAND_MAX_TIMEOUT = "600000";

    PAGER = "less -FR";

    CLICOLOR = "1";
  }
  // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    SSH_AUTH_SOCK = "/run/user/$(id -u)/ssh-agent";
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/%r@%h-%p";
    controlPersist = "600";
    serverAliveInterval = 60;
    serverAliveCountMax = 2;
    compression = true;

    extraConfig = ''
      # Security settings
      Protocol 2
      HashKnownHosts yes

      # Performance
      Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

      # Convenience
      AddKeysToAgent yes
      ForwardAgent yes
    '';
  };

  # Create SSH sockets directory
  home.file.".ssh/sockets/.keep".text = "";

  # Alacritty terminal configuration
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "xterm-256color";
      };

      window = {
        padding = {
          x = 24;
          y = 24;
        };
        opacity = 1.0;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        option_as_alt = "Both";
      };

      font = {
        normal = {
          family = "MesloLGS Nerd Font";
          style = "Regular";
        };
        size = if pkgs.stdenv.isDarwin then 14 else 10;
      };

      colors = {
        # Gruvbox dark theme
        primary = {
          background = "0x1d2021";
          foreground = "0xebdbb2";
        };
        cursor = {
          text = "0x1d2021";
          cursor = "0xebdbb2";
        };
        normal = {
          black = "0x282828";
          red = "0xcc241d";
          green = "0x98971a";
          yellow = "0xd79921";
          blue = "0x458588";
          magenta = "0xb16286";
          cyan = "0x689d6a";
          white = "0xa89984";
        };
        bright = {
          black = "0x928374";
          red = "0xfb4934";
          green = "0xb8bb26";
          yellow = "0xfabd2f";
          blue = "0x83a598";
          magenta = "0xd3869b";
          cyan = "0x8ec07c";
          white = "0xebdbb2";
        };
      };

      cursor = {
        style = "Block";
        unfocused_hollow = true;
      };

      selection = {
        save_to_clipboard = true;
      };

      mouse = {
        hide_when_typing = true;
      };
    };
  };

  # Readline configuration
  home.file.".inputrc".text = ''
    # Enable vi mode
    set editing-mode vi
    set keymap vi-command

    # Show which mode we're in
    set show-mode-in-prompt on
    set vi-ins-mode-string \1\e[6 q\2
    set vi-cmd-mode-string \1\e[2 q\2

    # Better completion
    set completion-ignore-case on
    set completion-prefix-display-length 3
    set mark-symlinked-directories on
    set show-all-if-ambiguous on
    set show-all-if-unmodified on
    set visible-stats on

    # History search
    "\e[A": history-search-backward
    "\e[B": history-search-forward
  '';
}
