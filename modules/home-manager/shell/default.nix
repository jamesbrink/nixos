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

    CLAUDE_BASH_COMMAND_TIMEOUT = "600000";
    CLAUDE_BASH_COMMAND_MAX_TIMEOUT = "600000";

    PAGER = "less -FR";

    CLICOLOR = "1";
    KUBECONFIG = "$HOME/.kube/config";

    # Add ~/.local/bin to PATH
    PATH = "$HOME/.local/bin:$PATH";
  }
  // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    SSH_AUTH_SOCK = "/run/user/$(id -u)/ssh-agent";
  };

  # SSH configuration
  # TODO: Research which specific option(s) were causing SSH hangs on Darwin (halcyon)
  # The following options were disabled to resolve connection issues:
  # - ControlMaster/ControlPath/ControlPersist (connection multiplexing)
  # - SendEnv directives (environment variable propagation)
  # - Protocol 2 (deprecated)
  # - Custom Ciphers and MACs lists
  # - ForwardAgent
  # Once identified, we can selectively re-enable the non-problematic options
  programs.ssh = {
    enable = true;
    # Disable default config since we define our own matchBlocks."*"
    enableDefaultConfig = false;
    matchBlocks."*" = {
      serverAliveInterval = 60;
      serverAliveCountMax = 2;
      compression = true;
    };

    extraConfig = ''
      # COMMENTED OUT: SendEnv can cause issues if remote server doesn't accept these
      # # Propagate locale/terminal information to remote hosts
      # SendEnv LANG
      # SendEnv LC_*
      # SendEnv TERM
      # SendEnv COLORTERM
      # SendEnv LC_TERMINAL
      # SendEnv LC_TERMINAL_VERSION
      # SendEnv COLORFGBG

      # Security settings
      # COMMENTED OUT: Protocol 2 is deprecated (SSH2 is the only protocol now)
      # Protocol 2
      HashKnownHosts yes

      # COMMENTED OUT: Custom cipher/MAC lists can cause compatibility issues
      # # Performance
      # Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      # MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

      # Convenience
      AddKeysToAgent yes
      # COMMENTED OUT: ForwardAgent can cause issues and is a security risk
      # ForwardAgent yes

      # Local NixOS/Darwin hosts
      # NOTE: Using only FQDNs here for VSCode Remote SSH compatibility
      # VSCode has issues parsing multiple hostnames per Host entry
      # The 00-local-hosts include file has both short and FQDN names for CLI usage

      Host alienware.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host hal9000.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host halcyon.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host sevastopol.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host n100-01.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host n100-02.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host n100-03.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host n100-04.home.urandom.io
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null

      Host server01
        StrictHostKeyChecking no
        CheckHostIP no
        UserKnownHostsFile=/dev/null
    '';
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    enableDefaultConfig = false;
  };

  # Create SSH sockets directory
  home.file.".ssh/sockets/.keep".text = "";

  # Alacritty terminal configuration
  programs.alacritty = {
    enable = true;
    settings = {
      # Import runtime theme colors (themectl manages the symlink)
      general.import = [ "${config.home.homeDirectory}/.config/omarchy/current/theme/alacritty.toml" ];

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
        decorations = "buttonless"; # Hide title bar on macOS for cleaner look
      };

      font = {
        normal = {
          family = "MesloLGS Nerd Font";
          style = "Regular";
        };
        size = if pkgs.stdenv.isDarwin then 14 else 10;
      };

      # Commented out: now using runtime theme import (themectl)
      # colors = {
      #   # Rosé Pine theme
      #   primary = {
      #     background = "0x191724";
      #     foreground = "0xe0def4";
      #   };
      #   cursor = {
      #     text = "0x191724";
      #     cursor = "0xe0def4";
      #   };
      #   normal = {
      #     black = "0x26233a";
      #     red = "0xeb6f92";
      #     green = "0x31748f";
      #     yellow = "0xf6c177";
      #     blue = "0x9ccfd8";
      #     magenta = "0xc4a7e7";
      #     cyan = "0xebbcba";
      #     white = "0xe0def4";
      #   };
      #   bright = {
      #     black = "0x6e6a86";
      #     red = "0xeb6f92";
      #     green = "0x31748f";
      #     yellow = "0xf6c177";
      #     blue = "0x9ccfd8";
      #     magenta = "0xc4a7e7";
      #     cyan = "0xebbcba";
      #     white = "0xe0def4";
      #   };
      # };

      cursor = {
        style = "Block";
        unfocused_hollow = true;
      };

      selection = {
        save_to_clipboard = true;
      };

      mouse = {
        hide_when_typing = false;
      };

      keyboard = {
        bindings = [
          # Clear screen on Command+K (macOS)
          {
            key = "K";
            mods = "Command";
            action = "ClearHistory";
          }
          # Also bind Command+K to send the clear sequence
          {
            key = "K";
            mods = "Command";
            chars = "\\u000c";
          }
          # Font scaling for BSP mode (avoid cmd +/- tiling bindings)
          {
            key = "Equals";
            mods = "Command|Option";
            action = "IncreaseFontSize";
          }
          {
            key = "Minus";
            mods = "Command|Option";
            action = "DecreaseFontSize";
          }
        ];
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
