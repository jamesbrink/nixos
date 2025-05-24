{
  config,
  lib,
  pkgs,
  inputs,
  claude-desktop,
  secretsPath,
  ...
}@args:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
    ../../modules/shared-packages/agenix.nix
    (import ../../users/regular/jamesbrink.nix {
      inherit
        config
        pkgs
        inputs
        secretsPath
        ;
      unstablePkgs = pkgs.unstablePkgs;
      inherit claude-desktop;
    })
    ../../profiles/desktop/default-stable.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

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

  boot.loader.grub = {
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

  networking.hostId = "ce7b643e";
  networking.hostName = "n100-04";
  networking.networkmanager.enable = true;

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

  environment.systemPackages = with pkgs; [
    distrobox
    podman
    vim
    wget
  ];

  # Configure age secrets for SSH host keys
  age.secrets."ssh_host_ed25519_key" = {
    file = "${inputs.secrets}/secrets/n100-04/ssh/host-ed25519-key.age";
    path = "/etc/ssh/ssh_host_ed25519_key";
    mode = "0600";
    owner = "root";
    group = "root";
  };

  age.secrets."ssh_host_rsa_key" = {
    file = "${inputs.secrets}/secrets/n100-04/ssh/host-rsa-key.age";
    path = "/etc/ssh/ssh_host_rsa_key";
    mode = "0600";
    owner = "root";
    group = "root";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
    };
    hostKeys = [
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
  };

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
    };
    ssh = {
      startAgent = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
    tmux = {
      enable = true;
      terminal = "screen-256color";
      historyLimit = 10000;
    };
    mosh.enable = true;
    firefox.enable = true;
    appimage = {
      enable = true;
      binfmt = true;
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;
      configure = {
        packages.myVimPackage = with pkgs.vimPlugins; {
          start = [
            ansible-vim
            nvim-treesitter
            nvim-treesitter-parsers.c
            nvim-treesitter-parsers.lua
            nvim-treesitter-parsers.nix
            nvim-treesitter-parsers.terraform
            nvim-treesitter-parsers.vimdoc
            nvim-treesitter-parsers.python
            nvim-treesitter-parsers.ruby
            telescope-nvim
            vim-terraform
          ];
        };
        customRC = ''
          syntax on
          filetype plugin indent on
          set title
          set number
          set hidden
          set encoding=utf-8
          set title
        '';
      };
    };
  };

  users.defaultUserShell = pkgs.zsh;
  networking.firewall.enable = false;
  system.stateVersion = "23.11";
}
