{
  config,
  pkgs,
  lib,
  inputs,
  claude-desktop,
  secretsPath,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
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

  boot = {
    kernel.sysctl."kernel.dmesg_restrict" = 0;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  services.pulseaudio.enable = false;

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;
    }
  ];

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  networking = {
    hostName = "n100-01";
    domain = "home.urandom.io";
    networkmanager.enable = true;
    hosts = {
      "127.0.0.1" = [
        "localhost"
        "${config.networking.hostName}"
      ];
    };
    firewall.enable = false;
  };

  services = {
    rpcbind.enable = true;
    printing.enable = true;
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

  security.rtkit.enable = true;

  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    secrets = {
      "secrets/global/ssh/authorized_keys.age".file =
        "${secretsPath}/secrets/global/ssh/authorized_keys.age";
    };
  };

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      enableNvidia = false;
    };
    incus.enable = true;
    vswitch.enable = true;
    libvirtd.enable = true;
  };

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

  environment = {
    shells = with pkgs; [ zsh ];
    variables = {
      EDITOR = "vim";
      OLLAMA_HOST = "desktop2";
    };
  };

  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
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

  system.stateVersion = "24.05";
}
