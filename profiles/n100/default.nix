# Shared configuration for N100 cluster nodes
{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:
{
  imports = [
    ../../modules/n100-disko.nix
    ../../modules/restic-backups.nix
    ../../modules/services/samba-server.nix
    ../../modules/services/k3s.nix
    ../../profiles/server/default.nix
    # Desktop profile - uncomment for RustDesk server mode (X11/XFCE)
    # ../../profiles/desktop/xfce.nix
    ../../users/regular/jamesbrink.nix
  ];

  # Basic Nix configuration
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Limit build parallelism for N100's 4-core CPU to prevent kernel hangs
      max-jobs = 2; # Maximum parallel builds
      cores = 2; # CPU cores per build job
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  # Boot configuration for ZFS
  boot = {
    # Enable aarch64-linux emulation for building ARM Docker images
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    # Use GRUB for ZFS support
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
        copyKernels = true;
      };
      efi.canTouchEfiVariables = false;
    };

    # ZFS support
    supportedFilesystems = [ "zfs" ];
    zfs = {
      forceImportRoot = false;
      devNodes = "/dev/disk/by-id";
    };

    # Pin to LTS kernel for ZFS stability (6.6 is LTS until Dec 2026)
    kernelPackages = pkgs.linuxPackages_6_6;

    # Kernel parameters for stability and auto-recovery
    kernel.sysctl = {
      "kernel.dmesg_restrict" = 0;
      "kernel.panic" = 30; # Auto-reboot 30 seconds after kernel panic
      "kernel.panic_on_oops" = 1; # Treat oops as panic to trigger reboot
    };

    # Load iTCO watchdog module
    kernelModules = [ "iTCO_wdt" ];
  };

  # ZFS services
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot = {
      enable = true;
      frequent = 4;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
  };

  # Prevent sleep/hibernation
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Enable hardware watchdog for automatic recovery from hangs
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "60s"; # Ping watchdog every 60 seconds
    RebootWatchdogSec = "2min"; # Force reboot if no ping for 2 minutes
  };

  # Enable systemd-oomd for memory pressure handling
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  # Power management for Intel N100
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance"; # N100's intel_pstate only supports performance/powersave
  };

  # Intel thermal management daemon for better thermal control
  services.thermald.enable = true;

  # Networking
  networking = {
    # Commented out to prevent *.home.urandom.io wildcard DNS from intercepting external domains
    # domain = "home.urandom.io";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  # Avoid configuring any search domains so pods inherit the defaults
  services.resolved = {
    enable = true;
    domains = [ ];
  };

  # Services
  services = {
    openssh = {
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
  };

  # NFS server configuration for exporting shares
  services.nfs.server = {
    enable = true;
    exports = ''
      # Export /export directory to local network with full permissions
      /export 192.168.0.0/16(rw,sync,no_subtree_check,no_root_squash,insecure,all_squash,anonuid=1000,anongid=100)
      /export 10.0.0.0/8(rw,sync,no_subtree_check,no_root_squash,insecure,all_squash,anonuid=1000,anongid=100)
    '';
  };

  # Samba server configuration - sharing same paths as NFS
  services.samba-server = {
    enable = true;
    workgroup = "WORKGROUP";
    serverString = "N100 Cluster Node";
    enableWSDD = true; # Enable Windows 10/11 network discovery
    allowedNetworks = [
      "192.168.0.0/16"
      "10.0.0.0/8"
    ];
    shares = {
      export = {
        path = "/export";
        comment = "N100 shared storage";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
    };
  };

  # K3s Kubernetes cluster configuration (worker nodes)
  services.k3s-cluster = {
    enable = true;
    role = "agent";
    serverUrl = "https://hal9000.home.urandom.io:6443";
    users = [ "jamesbrink" ];
    admins = [ "jamesbrink" ];
    # hostname will be set per-host
    domain = "home.urandom.io";
    maxPods = 110; # Default for smaller nodes
    storagePoolDataset = "zpool/k3s"; # Using zpool on n100 nodes (not rpool)
    storageMountpoint = "/var/lib/rancher";
    enableTraefik = false; # Only on master node
    enableGpuSupport = false; # N100 nodes don't have NVIDIA GPUs
    runnerTierLabel = "selfhost-s";
  };

  # Avahi for macOS discovery (Bonjour)
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

  # Create the export directory with full permissions
  systemd.tmpfiles.rules = [
    "d /export 0777 root root -"
  ];

  # K3s storage - ZFS dataset must be created manually:
  # zfs create -o mountpoint=legacy -o compression=lz4 zpool/k3s
  fileSystems."/var/lib/rancher" = {
    device = "zpool/k3s";
    fsType = "zfs";
    options = [ "nofail" ];
  };

  # Age secrets
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "global-ssh-authorized-keys".file = "${secretsPath}/global/ssh/authorized_keys.age";
      # k3s-token is set per host
    };
  };

  # Virtualization
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
    };
  };

  # Time and locale
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

  # Environment
  environment = {
    shells = with pkgs; [ zsh ];
    variables = {
      EDITOR = "vim";
    };
  };

  # Programs
  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
    };
    mosh.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;
    };
  };

  users.defaultUserShell = pkgs.zsh;

  system.stateVersion = "25.05";
}
