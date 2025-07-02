# Linux-specific user configuration
{
  config,
  pkgs,
  lib,
  secretsPath ? null,
  ...
}:

let
  # Get these from specialArgs or use defaults
  inputs = config._module.args.inputs or { };
  # Use the secretsPath from function arguments if available, otherwise try from module args
  effectiveSecretsPath =
    if secretsPath != null then
      secretsPath
    else if (config._module.args.secretsPath or null) != null then
      config._module.args.secretsPath
    else if (inputs.secrets or null) != null then
      inputs.secrets
    else
      "./secrets"; # Fallback for remote deployments
  claude-desktop = config._module.args."claude-desktop" or inputs."claude-desktop" or null;
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
    ];
  };

  # User packages
  home-manager.users.jamesbrink =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          # Common packages
          atuin
          ffmpeg-full
          imagemagick
          nushell
          tldr
          xonsh
          yt-dlp

          # Linux-specific packages
          (pkgs.callPackage ../../pkgs/llama-cpp {
            cudaSupport = true;
            cudaPackages = pkgs.cudaPackages_12_3;
          })
        ]
        ++ (
          if claude-desktop != null then
            [ claude-desktop.packages.${pkgs.system}.default ]
          else
            builtins.trace "WARNING: claude-desktop is null" []
        )
        ++ [
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
          jetbrains.datagrip
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
          unstable.code-cursor
          unstable.goose-cli
          unstable.windsurf
          warp-terminal
          waveterm
          wezterm
          winbox4
          wireshark
        ];
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
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  age.secrets."aws-config" = {
    file = "${effectiveSecretsPath}/secrets/jamesbrink/aws/config.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  age.secrets."aws-credentials" = {
    file = "${effectiveSecretsPath}/secrets/jamesbrink/aws/credentials.age";
    owner = "jamesbrink";
    group = "users";
    mode = "0600";
  };

  # Linux-specific systemd service
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
