{
  config,
  pkgs,
  lib,
  secretsPath,
  inputs,
  self,
  ...
}@args:

{
  disabledModules = [
    "services/misc/ollama.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    ../../profiles/desktop/hyprland.nix
    ../../modules/nix-caches.nix
    ../../modules/nix-limits.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/shared-packages/devops.nix
    ../../modules/restic-backups.nix
    ../../modules/services/samba-server.nix
    ../../modules/services/k3s.nix
    ../../users/regular/jamesbrink.nix
    (import "${args.inputs.nixos-unstable}/nixos/modules/services/misc/ollama.nix")
  ];

  # Security audit configuration
  security.audit.enable = false;
  security.auditd.enable = false;
  security.audit.failureMode = "printk";
  security.audit.rules = [
    "-a exit,always -F arch=b64 -S execve"
    "-w /etc/passwd -p wa -k passwd_changes"
    "-w /etc/shadow -p wa -k shadow_changes"
    "-w /var/log/audit/ -p wa -k audit_logs"
  ];

  # Nix configuration
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Allow remote build requests from trusted users
      trusted-users = [
        "root"
        "jamesbrink"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Home-manager configuration
  home-manager.backupFileExtension = "backup";

  # Boot configuration
  boot = {
    # Enable aarch64-linux emulation for building ARM Docker images
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernel.sysctl."kernel.dmesg_restrict" = 0;
  };

  # Mount second drive (Data)
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/d62b78a4-d4b6-4b81-b3e5-cc7baa98ba36";
    fsType = "ext4";
    options = [
      "users"
      "nofail"
    ];
  };

  # Mount 8TB USB
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/be35c200-fa3e-499c-a638-19ee53e32478";
    fsType = "ext4";
    options = [
      "users"
      "nofail"
    ];
  };

  fileSystems."/export/storage" = {
    device = "/mnt/storage";
    options = [ "bind" ];
  };

  fileSystems."/export/data" = {
    device = "/mnt/data";
    options = [ "bind" ];
  };

  # NFS Server configuration
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export           10.70.100.0/24(rw,fsid=0,no_subtree_check)
    /export/storage   10.70.100.0/24(rw,nohide,insecure,no_subtree_check)
    /export/data      10.70.100.0/24(rw,nohide,insecure,no_subtree_check)
  '';

  # Samba server configuration - sharing same paths as NFS
  services.samba-server = {
    enable = true;
    workgroup = "WORKGROUP";
    serverString = "Alienware Samba Server";
    enableWSDD = true; # Enable Windows 10/11 network discovery
    shares = {
      export = {
        path = "/export";
        comment = "Alienware export root";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
      storage = {
        path = "/export/storage";
        comment = "8TB USB storage";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
      data = {
        path = "/export/data";
        comment = "Data drive";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
    };
  };

  # Networking configuration
  networking = {
    hostName = "alienware";
    # Commented out to prevent *.home.urandom.io wildcard DNS from intercepting external domains
    # domain = "home.urandom.io";
    networkmanager.enable = true;
  };

  # Override systemd-resolved global search domains to prevent wildcard DNS conflicts
  services.resolved = {
    enable = true;
    domains = [ ];
  };

  # K3s Kubernetes cluster worker node with GPU support
  services.k3s-cluster = {
    enable = true;
    role = "agent";
    serverUrl = "https://hal9000.home.urandom.io:6443";
    users = [ "jamesbrink" ];
    admins = [ "jamesbrink" ];
    hostname = "alienware";
    domain = "home.urandom.io";
    maxPods = 500;
    storagePoolDataset = ""; # Not used - using directory mount
    storageMountpoint = "/var/lib/rancher";
    enableTraefik = false; # Only on master node
    enableGpuSupport = true;
    nodeLabels = {
      "nvidia.com/gpu.present" = "true";
      "nvidia.com/gpu" = "true";
      "gpu-model" = "alienware-gpu";
      "node-role" = "worker";
    };
    runnerTierLabel = "selfhost-m";
  };

  # Create k3s storage directory and AI directory for ComfyUI
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher 0755 root root -"
    "d /home/jamesbrink/AI 0755 jamesbrink users -"
  ];

  # Time and locale configuration
  time.timeZone = "America/Phoenix";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # nix-ld configuration for dynamic linking
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    autoconf
    binutils
    cudatoolkit
    curl
    freeglut
    git
    gitRepo
    gnumake
    gnupg
    gperf
    libGL
    libGLU
    linuxPackages.nvidia_x11
    m4
    ncurses5
    openssl
    procps
    stdenv.cc
    stdenv.cc.cc
    unzip
    util-linux
    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXmu
    xorg.libXrandr
    xorg.libXv
    zlib
  ];

  # Touchpad configuration (physical buttons broken)
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true; # Tap to click
      tappingButtonMap = "lrm"; # 1-finger=left, 2-finger=right, 3-finger=middle
      clickMethod = "clickfinger"; # Use finger count for clicks
      naturalScrolling = true; # Optional: reverse scroll direction
      disableWhileTyping = true; # Prevent accidental touches while typing
    };
  };

  # Sound configuration with PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # Ollama AI service with CUDA support
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    package = pkgs.unstablePkgs.ollama-cuda;
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "*"; # Allow all origins (CORS)
    };
  };

  # ComfyUI service
  services.comfyui = {
    enable = true;
    cuda = true;
    enableManager = true;
    port = 8188;
    listenAddress = "0.0.0.0";
    dataDir = "/home/jamesbrink/AI";
    user = "jamesbrink";
    group = "users";
    createUser = false;
    extraArgs = [
      "--use-pytorch-cross-attention"
      "--cuda-malloc"
      "--lowvram"
    ];
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # NVIDIA GPU configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  hardware.nvidia-container-toolkit.enable = true;

  # NVIDIA environment variables for container runtime
  environment.variables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Sunshine game streaming
  systemd.user.services.sunshine = {
    description = "Sunshine self-hosted game stream host for Moonlight";
    startLimitBurst = 5;
    startLimitIntervalSec = 500;
    serviceConfig = {
      ExecStart = "${config.security.wrapperDir}/sunshine";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  # VSCode Server (commented out)

  # Syncthing configuration
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
        passwordFile = config.age.secrets."alienware-syncthing-password".path;
      };
      devices = {
        "DarkStarMk6Mod1" = {
          autoAcceptFolders = true;
          id = "A46R3HQ-AW3ODFH-RVOAW4C-P6VFHO5-KHIBRP2-PQLRKIE-YAZTGQO-7QGPCAF";
        };
        "Alienware15R4" = {
          id = "LQKOQMG-AIDPDJU-AICPMA4-UPLKWUP-PTWHUNL-IRNJIWD-GY2VU3Q-JLMG6QB";
          autoAcceptFolders = true;
        };
        "N100-01" = {
          autoAcceptFolders = true;
          id = "HCRYHXP-QXLM4FW-SIPYBNL-IOLODXZ-PM5FX7W-3DOQ4ED-GJ5YNSK-LVUJQAA";
        };
        "N100-02" = {
          autoAcceptFolders = true;
          id = "KICZH4D-WJIVHZM-EW2CN5A-WEF44ZA-VAXR7MY-AWTQOXC-APLRSQP-TQCOBQX";
        };
        "N100-03" = {
          autoAcceptFolders = true;
          id = "WYTVEJT-WTMRX73-N3ASBH2-AAHMD5R-N3FUI3M-XXYQAVH-O6GDDU4-LUQVHAT";
        };
      };
      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [
            "DarkStarMk6Mod1"
            "Alienware15R4"
          ];
          label = "Projects";
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [
            "DarkStarMk6Mod1"
            "Alienware15R4"
          ];
          label = "Documents";
        };
      };
    };
  };

  # Shell configuration

  # SSH configuration with age secrets
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      LoginGraceTime = 0;
      AuthorizedKeysCommand = "${pkgs.bash}/bin/bash -c 'cat ${
        config.age.secrets."global-ssh-authorized-keys".path
      }'";
      AuthorizedKeysCommandUser = "root";
    };
  };

  # Age secrets configuration
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "global-ssh-authorized-keys".file = "${secretsPath}/global/ssh/authorized_keys.age";
      "alienware-syncthing-password".file = "${secretsPath}/alienware/syncthing-password.age";
      "k3s-token".file = "${secretsPath}/alienware/k3s-token.age";
    };
  };

  # Virtualization configuration
  virtualisation = {
    containers = {
      enable = true;
      # Runtime configuration using the correct NixOS structure
      containersConf.settings = {
        containers = {
          default_sysctls = [ ];
        };
      };
      # Specify crun as the OCI runtime
      ociSeccompBpfHook.enable = true;
    };
    podman = {
      enable = true;
      dockerCompat = false; # Disable docker compatibility to use real Docker
      defaultNetwork.settings.dns_enabled = true;
      extraPackages = with pkgs; [
        runc
        crun
        conmon
      ];
    };
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      daemon.settings = {
        features = {
          buildkit = true;
        };
      };
      # NVIDIA GPU support is configured via hardware.nvidia-container-toolkit.enable = true
    };
    vmware.guest.enable = true;
    incus.enable = true;
    vswitch.enable = true;
    libvirtd.enable = true;
  };

  # Remote desktop services
  services.gnome.gnome-remote-desktop.enable = true;

  # Sudo configuration
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

  # Service discovery and VPN
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable mDNS name resolution
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=RackMac</txt-record>
          </service>
        </service-group>
      '';
    };
  };
  services.tailscale.enable = true;

  # Steam gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Additional programs
  programs.firefox.enable = true;
  programs.mosh.enable = true;

  # System services
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Host-specific packages (beyond what's in shared modules and desktop profile)
  environment.systemPackages = with pkgs; [

    # CUDA and GPU tools
    cudaPackages.cudatoolkit
    nvtopPackages.nvidia

    # Storage and filesystem tools
    gparted
    hdparm
    hfsprogs
    libxisf
    zfs

    # Virtualization tools
    open-vm-tools
    openvswitch
    podman
    podman-compose
    vagrant

    # Gaming and streaming
    sunshine
    steam
    wineWowPackages.full

    # Development tools not in shared packages
    cmake
    gcc
    python313Packages.boto3
    python313Packages.pip
    python313Packages.pynvim
    rustfmt
    rustup

    # Specific tools
    alacritty-theme
    exo
    fly
    gitea
    gitlab
    headscale
    k3s
    k6
    kind
    kops
    lego
    libxisf
    mkdocs
    mtr-gui
    nodenv
    nushell
    packer
    pyenv
    restique
    slack-cli
    slack-term
    spin
    sublime
    tigervnc
    vscode-extensions.adpyke.codesnap
    vscode-extensions.twxs.cmake
    xorg.xinit
    xrdp
    zellij
  ];

  # Power management
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Firewall configuration (disabled for home network)
  networking.firewall = {
    enable = false;
    allowedTCPPorts = [
      22 # SSH
      3389 # RDP
      47984 # Sunshine
      47989 # Sunshine
      47990 # Sunshine
      48010 # Sunshine
      7865 # Custom service
      8188 # ComfyUI web UI
    ];
    allowedUDPPortRanges = [
      {
        from = 47998;
        to = 48000;
      }
      {
        from = 8000;
        to = 8010;
      }
    ];
  };

  # System state version
  system.stateVersion = "25.05";
}
