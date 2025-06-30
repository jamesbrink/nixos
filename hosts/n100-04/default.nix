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
    ./hardware-configuration.nix
    ../../profiles/server/default.nix
    ../../modules/shared-packages/agenix.nix
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
    kernel.sysctl."kernel.dmesg_restrict" = 0;
    loader.grub = {
      enable = true;
      zfsSupport = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      mirroredBoots = [
        {
          devices = [ "nodev" ];
          path = "/boot";
        }
      ];
    };
  };

  # ZFS filesystems
  fileSystems."/" = {
    device = "zpool/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "zpool/nix";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "zpool/var";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zpool/home";
    fsType = "zfs";
  };

  swapDevices = [ ];

  # Prevent sleep/hibernation
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Networking
  networking = {
    hostId = "ce7b643e"; # Required for ZFS
    hostName = "n100-04";
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
          config.age.secrets."secrets/global/ssh/authorized_keys.age".path
        }'";
        AuthorizedKeysCommandUser = "root";
      };
    };
  };

  # NFS mount for shared storage
  systemd.mounts = [
    {
      type = "nfs";
      mountConfig.Options = "noatime";
      what = "alienware.home.urandom.io:/storage";
      where = "/mnt/storage";
    }
  ];

  systemd.automounts = [
    {
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "600";
      where = "/mnt/storage";
    }
  ];

  # Age secrets with SSH host keys
  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      "secrets/global/ssh/authorized_keys.age".file =
        "${secretsPath}/secrets/global/ssh/authorized_keys.age";

      # Host-specific SSH keys
      "ssh_host_ed25519_key" = {
        file = "${inputs.secrets}/secrets/n100-04/ssh/host-ed25519-key.age";
        path = "/etc/ssh/ssh_host_ed25519_key";
        mode = "0600";
        owner = "root";
        group = "root";
      };
      "ssh_host_rsa_key" = {
        file = "${inputs.secrets}/secrets/n100-04/ssh/host-rsa-key.age";
        path = "/etc/ssh/ssh_host_rsa_key";
        mode = "0600";
        owner = "root";
        group = "root";
      };
    };
  };

  # SSH host key configuration
  services.openssh.hostKeys = [
    {
      path = config.age.secrets."ssh_host_ed25519_key".path;
      type = "ed25519";
    }
    {
      path = config.age.secrets."ssh_host_rsa_key".path;
      type = "rsa";
      bits = 4096;
    }
  ];

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
