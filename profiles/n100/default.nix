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
    ../../profiles/server/default.nix
    ../../profiles/desktop/default.nix
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

    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    kernel.sysctl."kernel.dmesg_restrict" = 0;
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

  # Networking
  networking = {
    domain = "home.urandom.io";
    networkmanager.enable = true;
    firewall.enable = false;
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

  # Age secrets
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "global-ssh-authorized-keys".file = "${secretsPath}/global/ssh/authorized_keys.age";
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
