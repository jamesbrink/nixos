# Linux-specific user configuration
{
  config,
  pkgs,
  lib,
  inputs ? { },
  secretsPath ? null,
  ...
}:

let
  # Get inputs from module args if not passed as parameter
  effectiveInputs = if inputs != { } then inputs else config._module.args.inputs or { };
  # Use the secretsPath from function arguments if available, otherwise try from module args
  effectiveSecretsPath =
    if secretsPath != null then
      secretsPath
    else if (config._module.args.secretsPath or null) != null then
      config._module.args.secretsPath
    else if (effectiveInputs.secrets or null) != null then
      effectiveInputs.secrets
    else
      "./secrets"; # Fallback for remote deployments
  unstablePkgs = config._module.args.unstablePkgs or pkgs.unstablePkgs or pkgs;
  unstable = unstablePkgs;
in
{
  imports = [
    ./jamesbrink-shared.nix
    ../../modules/claude-desktop.nix
    ../../modules/ghostty-terminfo.nix
  ];

  # Linux user configuration
  users.users.jamesbrink = {
    isNormalUser = true;
    uid = 1000;
    description = "James Brink";
    createHome = true;
    extraGroups = [
      "docker"
      "incus-admin"
      "kvm"
      "libvirtd"
      "networkmanager"
      "qemu-libvirtd"
      "wheel"
      "input"
    ];
    shell = pkgs.zsh;
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      # SSH public keys for user jamesbrink
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArPfE2X8THR73peLxwMfd4uCXH8A3moM/T1l+HvgDva" # ViteTunnel
      # System keys
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARkb1kXdTi41j9j9JLPtY1+HxskjrSCkqyB5Dx0vcqj root@Alienware15R4"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkFHSY+3XcW54uu4POE743wYdh4+eGIR68O8121X29m root@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRNDnoVLI8Zy9YjOkHQuX6m9f9EzW8W2lYxnoGDjXtM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSf4Qft9nUD2gRDeJVkogYKY7PQvhlnD+kjFKgro3r"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKlaSFMo6Wcm5oZu3ABjPY4Q+INQBlVwxVktjfz66oI root@n100-04"
    ];
  };

  # User packages
  home-manager.users.jamesbrink =
    { pkgs, ... }:
    {
      # Make inputs available to home-manager
      _module.args = {
        inputs = effectiveInputs;
      };

      # Allow unfree packages in home-manager
      nixpkgs.config.allowUnfree = true;

      # Hyprland user configuration
      wayland.windowManager.hyprland = {
        enable = true;
        settings = {
          # Omarchy-style keybindings
          "$mod" = "SUPER";

          # Startup services
          "exec-once" = [
            "wl-paste --type text --watch cliphist store" # Clipboard history for text
            "wl-paste --type image --watch cliphist store" # Clipboard history for images
          ];

          bind = [
            # Applications
            "$mod, RETURN, exec, alacritty"
            "$mod SHIFT, F, exec, thunar" # File manager
            "$mod SHIFT, B, exec, firefox"
            "$mod SHIFT ALT, B, exec, firefox --private-window"
            "$mod SHIFT, M, exec, spotify"
            "$mod SHIFT, N, exec, alacritty -e nvim"
            "$mod SHIFT, T, exec, alacritty -e btop"
            "$mod SHIFT, D, exec, alacritty -e lazydocker"
            "$mod SHIFT, G, exec, signal-desktop"
            "$mod SHIFT, O, exec, obsidian"
            # "$mod SHIFT, SLASH, exec, 1password"  # Passwords (not installed yet)

            # Web Apps (require wrapper scripts or direct launches)
            # "$mod SHIFT, A, exec, firefox --new-window https://chat.openai.com"
            # "$mod SHIFT ALT, A, exec, firefox --new-window https://grok.x.ai"
            # "$mod SHIFT, C, exec, firefox --new-window https://calendar.google.com"
            # "$mod SHIFT, E, exec, firefox --new-window https://mail.google.com"
            "$mod SHIFT, Y, exec, firefox --new-window https://youtube.com"
            # "$mod SHIFT ALT, G, exec, firefox --new-window https://web.whatsapp.com"
            # "$mod SHIFT CTRL, G, exec, firefox --new-window https://messages.google.com"
            # "$mod SHIFT, X, exec, firefox --new-window https://x.com"

            # Menus
            "$mod, SPACE, exec, rofi -show drun"
            "$mod CTRL, E, exec, rofi -show emoji"
            # "$mod ALT, SPACE, exec, omarchy-menu"  # Omarchy menu (not installed)
            "$mod, ESCAPE, exec, wlogout"
            # "$mod, K, exec, show-keybindings"  # Key bindings (custom script needed)

            # Window Management
            "$mod, W, killactive,"
            # "CTRL ALT, DELETE, exec, hyprctl clients | jq -r '.[].address' | xargs -I {} hyprctl dispatch closewindow address:{}"
            "$mod, J, togglesplit,"
            "$mod, P, pseudo,"
            "$mod, T, togglefloating,"
            "$mod, F, fullscreen, 0"
            "$mod CTRL, F, fullscreen, 1"
            # "$mod ALT, F, resizeactive, exact 100% 0"  # Full width
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"
            "$mod SHIFT, left, swapwindow, l"
            "$mod SHIFT, right, swapwindow, r"
            "$mod SHIFT, up, swapwindow, u"
            "$mod SHIFT, down, swapwindow, d"

            # Workspaces
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"
            "$mod, 0, workspace, 10"
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"
            "$mod SHIFT, 0, movetoworkspace, 10"
            "$mod, TAB, workspace, e+1"
            "$mod SHIFT, TAB, workspace, e-1"
            # "$mod CTRL, TAB, workspace, previous"  # Former workspace

            # Window Cycling
            "ALT, TAB, cyclenext,"
            "ALT SHIFT, TAB, cyclenext, prev"

            # Window Resizing
            "$mod, minus, resizeactive, -40 0"
            "$mod, equal, resizeactive, 40 0"
            "$mod SHIFT, minus, resizeactive, 0 -40"
            "$mod SHIFT, equal, resizeactive, 0 40"

            # Groups
            "$mod, G, togglegroup,"
            # "$mod ALT, G, moveoutofgroup"
            "$mod ALT, left, moveintogroup, l"
            "$mod ALT, right, moveintogroup, r"
            "$mod ALT, up, moveintogroup, u"
            "$mod ALT, down, moveintogroup, d"
            "$mod ALT, TAB, changegroupactive, f"
            "$mod ALT SHIFT, TAB, changegroupactive, b"

            # Clipboard
            "$mod, C, exec, wl-copy"
            "$mod, V, exec, wl-paste"
            "$mod, X, exec, wl-copy && wl-paste -c"
            "$mod CTRL, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

            # Captures (screenshots)
            ", PRINT, exec, grim -g \"$(slurp)\" - | swappy -f -"
            "SHIFT, PRINT, exec, grim -g \"$(slurp)\" - | wl-copy"
            # "ALT, PRINT, exec, wf-recorder"  # Screen recording
            # "$mod, PRINT, exec, hyprpicker -a"  # Color picker
            "$mod CTRL SHIFT, 3, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
            "$mod CTRL SHIFT, 4, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
            # "$mod CTRL SHIFT, 5, exec, hyprctl -j activewindow | jq -r '.at,.size' | grim -g - ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

            # Notifications (mako is installed in desktop profile)
            "$mod, comma, exec, makoctl dismiss"
            "$mod SHIFT, comma, exec, makoctl dismiss -a"
            "$mod CTRL, comma, exec, makoctl mode -t dnd"

            # Scroll workspace switching
            "$mod, mouse_down, workspace, e+1"
            "$mod, mouse_up, workspace, e-1"
          ];

          # Repeating bindings (for media keys)
          binde = [
            ", XF86AudioRaiseVolume, exec, pamixer -i 5"
            ", XF86AudioLowerVolume, exec, pamixer -d 5"
            ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
          ];

          # Non-repeating media bindings
          bindl = [
            ", XF86AudioMute, exec, pamixer -t"
            # ", XF86AudioMicMute, exec, pamixer --default-source -t"
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioNext, exec, playerctl next"
            ", XF86AudioPrev, exec, playerctl previous"
          ];

          # Mouse bindings
          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];
        };
      };

      home.packages =
        with pkgs;
        [
          # Common packages
          atuin
          ffmpeg-full
          imagemagick
          nushell
          xonsh
          yt-dlp

          # Linux-specific packages
          (pkgs.callPackage ../../pkgs/llama-cpp {
            cudaSupport =
              config.networking.hostName != "n100-01"
              && config.networking.hostName != "n100-02"
              && config.networking.hostName != "n100-03"
              && config.networking.hostName != "n100-04";
            cudaPackages = pkgs.cudaPackages_12_3;
          })
        ]
        ++ [
          # Desktop applications
          barrier
          dbeaver-bin
          discord
          drawio
          ferdium
          filezilla
          flameshot
          ghostty
          google-chrome
          insomnia
          unstable.jetbrains.datagrip
          legendary-gl
          lens
          mailspring
          meld
          obsidian
          openai-whisper-cpp
          unstable.postman
          unstable.signal-desktop
          termius
          unstable.claude-code
          unstable.goose-cli
          unstable.windsurf
          unstable.warp-terminal
          waveterm
          wezterm
          winbox4
          wireshark

          # User-specific Wayland/Hyprland apps
          spotify # Music player (commented out in keybindings)
          # 1password-gui # Password manager (if available)

          # Development tools
          lazydocker # Docker TUI (already in keybindings)

          # System utilities
          btop # System monitor (used in keybindings)
          xfce.thunar # File manager (used in keybindings)
          playerctl # Media player control

          # Customization tools
          pywal # Color scheme generator from wallpapers
          nwg-look # GTK theme configuration
          wdisplays # Display configuration GUI
        ];

      # Configure wlogout for proper Hyprland logout
      xdg.configFile."wlogout/layout".text = ''
        {
          "label" : "lock",
          "action" : "swaylock",
          "text" : "Lock",
          "keybind" : "l"
        }
        {
          "label" : "logout",
          "action" : "hyprctl dispatch exit",
          "text" : "Logout",
          "keybind" : "e"
        }
        {
          "label" : "shutdown",
          "action" : "systemctl poweroff",
          "text" : "Shutdown",
          "keybind" : "s"
        }
        {
          "label" : "reboot",
          "action" : "systemctl reboot",
          "text" : "Reboot",
          "keybind" : "r"
        }
      '';

      xdg.configFile."wlogout/style.css".text = ''
        * {
          background-image: none;
        }
        window {
          background-color: rgba(12, 12, 12, 0.9);
        }
        button {
          color: #FFFFFF;
          background-color: #1E1E1E;
          border-style: solid;
          border-width: 2px;
          background-repeat: no-repeat;
          background-position: center;
          background-size: 25%;
          border-radius: 10px;
          margin: 10px;
          min-width: 150px;
          min-height: 150px;
        }
        button:focus, button:active, button:hover {
          background-color: #3700B3;
          outline-style: none;
        }
      '';

      # Tokyo Night GTK theme configuration
      gtk = {
        enable = true;

        theme = {
          name = "Tokyonight-Dark";
          package = pkgs.tokyonight-gtk-theme;
        };

        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };

        cursorTheme = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = 24;
        };

        gtk3.extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };

        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };
      };

      # VSCode Tokyo Night theme configuration
      programs.vscode = {
        enable = true;
        userSettings = {
          "workbench.colorTheme" = "Tokyo Night";
          "workbench.iconTheme" = "material-icon-theme";
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
          "terminal.integrated.fontSize" = 13;
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace'";
          "editor.fontSize" = 14;
          "editor.fontLigatures" = true;
          "editor.formatOnSave" = true;
          "editor.minimap.enabled" = true;
          "workbench.startupEditor" = "none";
        };
        extensions = with pkgs.vscode-extensions; [
          enkia.tokyo-night
          pkief.material-icon-theme
        ];
      };

      # Alacritty Tokyo Night theme configuration (override shared config)
      programs.alacritty = {
        enable = true;
        settings = lib.mkForce {
          env = {
            TERM = "xterm-256color";
          };

          window = {
            padding = {
              x = 10;
              y = 10;
            };
            decorations = "full";
            opacity = 0.95;
          };

          font = {
            normal = {
              family = "JetBrainsMono Nerd Font";
              style = "Regular";
            };
            bold = {
              family = "JetBrainsMono Nerd Font";
              style = "Bold";
            };
            italic = {
              family = "JetBrainsMono Nerd Font";
              style = "Italic";
            };
            size = 12.0;
          };

          # Tokyo Night color scheme
          colors = {
            primary = {
              background = "#1a1b26";
              foreground = "#c0caf5";
            };

            normal = {
              black = "#15161e";
              red = "#f7768e";
              green = "#9ece6a";
              yellow = "#e0af68";
              blue = "#7aa2f7";
              magenta = "#bb9af7";
              cyan = "#7dcfff";
              white = "#a9b1d6";
            };

            bright = {
              black = "#414868";
              red = "#f7768e";
              green = "#9ece6a";
              yellow = "#e0af68";
              blue = "#7aa2f7";
              magenta = "#bb9af7";
              cyan = "#7dcfff";
              white = "#c0caf5";
            };

            indexed_colors = [
              {
                index = 16;
                color = "#ff9e64";
              }
              {
                index = 17;
                color = "#db4b4b";
              }
            ];
          };

          cursor = {
            style = "Block";
            unfocused_hollow = true;
          };

          selection = {
            save_to_clipboard = true;
          };
        };
      };
    };

  # Linux-specific sudo configuration
  security.sudo.extraRules = [
    {
      users = [ "jamesbrink" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Age configuration
  # Host key first for boot-time decryption, then user key for user-specific secrets
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  age.secrets."aws-config" = {
    file = "${effectiveSecretsPath}/jamesbrink/aws/config.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."aws-credentials" = {
    file = "${effectiveSecretsPath}/jamesbrink/aws/credentials.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."github-token" = {
    file = "${effectiveSecretsPath}/jamesbrink/github-token.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."pypi-key" = {
    file = "${effectiveSecretsPath}/jamesbrink/pypi-key.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."deadmansnitch-key" = {
    file = "${effectiveSecretsPath}/jamesbrink/deadmansnitch-key.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."heroku-key" = {
    file = "${effectiveSecretsPath}/jamesbrink/heroku-key.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."infracost-api-key" = {
    file = "${effectiveSecretsPath}/global/infracost/api-key.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  # Linux-specific systemd services
  systemd.services.aws-config-setup = {
    description = "Setup AWS configuration files";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "jamesbrink";
    };
    script = ''
      mkdir -p /home/jamesbrink/.aws
      cp ${config.age.secrets."aws-config".path} /home/jamesbrink/.aws/config
      cp ${config.age.secrets."aws-credentials".path} /home/jamesbrink/.aws/credentials
      chmod 600 /home/jamesbrink/.aws/config /home/jamesbrink/.aws/credentials
      chown jamesbrink:users /home/jamesbrink/.aws/config /home/jamesbrink/.aws/credentials
    '';
  };

  systemd.services.github-token-setup = {
    description = "Setup GitHub token environment";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "jamesbrink";
    };
    script = ''
      # Read the GitHub token and create a shell source file
      mkdir -p /home/jamesbrink/.config/environment.d
      echo "export GITHUB_TOKEN=\"$(cat ${
        config.age.secrets."github-token".path
      })\"" > /home/jamesbrink/.config/environment.d/github-token.sh
      chmod 600 /home/jamesbrink/.config/environment.d/github-token.sh
      chown jamesbrink:users /home/jamesbrink/.config/environment.d/github-token.sh
    '';
  };

  systemd.services.infracost-token-setup = {
    description = "Setup Infracost API key environment";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "jamesbrink";
    };
    script = ''
      # Read the Infracost API key and create a shell source file
      mkdir -p /home/jamesbrink/.config/environment.d
      echo "export INFRACOST_API_KEY=\"$(cat ${
        config.age.secrets."infracost-api-key".path
      })\"" > /home/jamesbrink/.config/environment.d/infracost-api-key.sh
      chmod 600 /home/jamesbrink/.config/environment.d/infracost-api-key.sh
      chown jamesbrink:users /home/jamesbrink/.config/environment.d/infracost-api-key.sh
    '';
  };

  systemd.services.pypi-token-setup = {
    description = "Setup PyPI token environment";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "jamesbrink";
    };
    script = ''
            # Read the PyPI token and create a shell source file
            mkdir -p /home/jamesbrink/.config/environment.d
            TOKEN="$(cat ${config.age.secrets."pypi-key".path})"
            cat > /home/jamesbrink/.config/environment.d/pypi-token.sh <<EOF
      export PYPI_TOKEN="$TOKEN"
      export PYPI_API_TOKEN="$TOKEN"
      export UV_PUBLISH_TOKEN="$TOKEN"
      export UV_PUBLISH_USERNAME="jamesbrink"
      export POETRY_PYPI_TOKEN_PYPI="$TOKEN"
      export TWINE_USERNAME="__token__"
      export TWINE_PASSWORD="$TOKEN"
      EOF
            chmod 600 /home/jamesbrink/.config/environment.d/pypi-token.sh
            chown jamesbrink:users /home/jamesbrink/.config/environment.d/pypi-token.sh
    '';
  };

  systemd.services.deadmansnitch-token-setup = {
    description = "Setup Dead Man's Snitch API key environment";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "jamesbrink";
    };
    script = ''
      # Read the Dead Man's Snitch API key and create a shell source file
      mkdir -p /home/jamesbrink/.config/environment.d
      echo "export DEADMANSNITCH_API_KEY=\"$(cat ${
        config.age.secrets."deadmansnitch-key".path
      })\"" > /home/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
      chmod 600 /home/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
      chown jamesbrink:users /home/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
    '';
  };

  # Enable Ghostty terminfo support
  programs.ghostty-terminfo.enable = true;

  # Syncthing service
  services.syncthing = {
    enable = true;
    user = "jamesbrink";
    dataDir = "/home/jamesbrink/";
    configDir = "/home/jamesbrink/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "0.0.0.0:8384";

    settings = {
      gui = {
        user = "jamesbrink";
        # Password should be set via web UI or environment
        # To use a secret, configure it at the system level in the host configuration
      };

      devices = {
        "darkstarmk6mod1" = {
          autoAcceptFolders = true;
          id = "A46R3HQ-AW3ODFH-RVOAW4C-P6VFHO5-KHIBRP2-PQLRKIE-YAZTGQO-7QGPCAF";
        };
        "alienware15r4" = {
          id = "LQKOQMG-AIDPDJU-AICPMA4-UPLKWUP-PTWHUNL-IRNJIWD-GY2VU3Q-JLMG6QB";
          autoAcceptFolders = true;
        };
        "n100-01" = {
          autoAcceptFolders = true;
          id = "HCRYHXP-QXLM4FW-SIPYBNL-IOLODXZ-PM5FX7W-3DOQ4ED-GJ5YNSK-LVUJQAA";
        };
        "n100-02" = {
          autoAcceptFolders = true;
          id = "KICZH4D-WJIVHZM-EW2CN5A-WEF44ZA-VAXR7MY-AWTQOXC-APLRSQP-TQCOBQX";
        };
        "n100-03" = {
          autoAcceptFolders = true;
          id = "WYTVEJT-WTMRX73-N3ASBH2-AAHMD5R-N3FUI3M-XXYQAVH-O6GDDU4-LUQVHAT";
        };
        "hal9000" = {
          autoAcceptFolders = true;
          id = "PRCPMWC-H6VGK4G-6X2QQDH-P6UOLJJ-JTLDNYW-LIKBC5X-6WM4T2R-Q5TZEAR";
        };
      };

      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [
            "darkstarmk6mod1"
            "alienware15r4"
            "n100-01"
            "n100-02"
            "n100-03"
            "hal9000"
          ];
          label = "Projects";
          enable = false;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [
            "darkstarmk6mod1"
            "alienware15r4"
            "n100-01"
            "n100-02"
            "n100-03"
            "hal9000"
          ];
          label = "Documents";
          enable = false;
        };
      };
    };
  };
}
