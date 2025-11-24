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
    hashedPasswordFile = config.age.secrets."jamesbrink-hashed-password".path;
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

  services.openssh.settings.AcceptEnv = lib.mkDefault (
    lib.concatStringsSep " " [
      "LANG"
      "LC_*"
      "TERM"
      "COLORTERM"
      "LC_TERMINAL"
      "LC_TERMINAL_VERSION"
      "COLORFGBG"
    ]
  );

  # User packages
  home-manager.users.jamesbrink =
    { pkgs, ... }:
    {
      imports =
        lib.optionals
          # Only import Hyprland desktop module on desktop systems (not headless servers)
          (
            config.networking.hostName != "n100-01"
            && config.networking.hostName != "n100-02"
            && config.networking.hostName != "n100-03"
            && config.networking.hostName != "n100-04"
          )
          [ ../../modules/home-manager/hyprland ];

      # Make inputs available to home-manager
      _module.args.inputs = effectiveInputs;

      # Allow unfree packages in home-manager
      nixpkgs.config.allowUnfree = true;

      home.packages =
        with pkgs;
        [
          # Common packages
          atuin
          ffmpeg-full
          gurk-rs
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

      # Custom desktop entries (Omarchy-style)
      xdg.desktopEntries = {
        imv = {
          name = "Image Viewer";
          exec = "imv %F";
          icon = "imv";
          type = "Application";
          mimeType = [
            "image/png"
            "image/jpeg"
            "image/jpg"
            "image/gif"
            "image/bmp"
            "image/webp"
            "image/tiff"
            "image/x-xcf"
            "image/x-portable-pixmap"
            "image/x-xbitmap"
          ];
          terminal = false;
          categories = [
            "Graphics"
            "Viewer"
          ];
        };

        mpv = {
          name = "Media Player";
          genericName = "Multimedia player";
          comment = "Play movies and songs";
          exec = "mpv --player-operation-mode=pseudo-gui -- %U";
          icon = "mpv";
          type = "Application";
          terminal = false;
          startupNotify = true;
          categories = [
            "AudioVideo"
            "Audio"
            "Video"
            "Player"
            "TV"
          ];
          mimeType = [
            "application/ogg"
            "audio/aac"
            "audio/mp3"
            "audio/mpeg"
            "audio/wav"
            "video/mp4"
            "video/mpeg"
            "video/x-matroska"
            "video/webm"
          ];
        };

        typora = {
          name = "Typora";
          genericName = "Markdown Editor";
          exec = "typora --enable-wayland-ime %U";
          icon = "typora";
          type = "Application";
          startupNotify = true;
          categories = [
            "Office"
            "WordProcessor"
          ];
          mimeType = [
            "text/markdown"
            "text/x-markdown"
          ];
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

  age.secrets."hal9000-kubeconfig" = {
    file = "${effectiveSecretsPath}/jamesbrink/k8s/hal9000-kubeconfig.age";
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

  age.secrets."jamesbrink-hashed-password" = {
    file = "${effectiveSecretsPath}/jamesbrink/hashed-password.age";
    owner = "root";
    group = "root";
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

  system.activationScripts.hal9000Kubeconfig = lib.mkAfter ''
    HAL_URL="https://hal9000.home.urandom.io:6443"
    ${pkgs.coreutils}/bin/install -d -m 700 -o jamesbrink -g users /home/jamesbrink/.kube
    TMP=$(${pkgs.coreutils}/bin/mktemp)
    ${pkgs.gnused}/bin/sed \
      -e "s|https://127.0.0.1:6443|$HAL_URL|g" \
      -e "s|https://localhost:6443|$HAL_URL|g" \
      ${config.age.secrets."hal9000-kubeconfig".path} > "$TMP"
    ${pkgs.coreutils}/bin/install -m 600 -o jamesbrink -g users "$TMP" /home/jamesbrink/.kube/config
    rm "$TMP"
  '';

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
