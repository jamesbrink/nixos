{ config, pkgs, lib, secretsPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
  ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  age.secrets = {
    "secrets/global/syncthing/DarkStarMk6Mod1-id.age".file = "${secretsPath}/secrets/global/syncthing/DarkStarMk6Mod1-id.age";
    "secrets/global/syncthing/Alienware15R4-id.age".file = "${secretsPath}/secrets/global/syncthing/Alienware15R4-id.age";
    "secrets/global/syncthing/N100-01-id.age".file = "${secretsPath}/secrets/global/syncthing/N100-01-id.age";
    "secrets/global/syncthing/N100-02-id.age".file = "${secretsPath}/secrets/global/syncthing/N100-02-id.age";
    "secrets/global/syncthing/N100-03-id.age".file = "${secretsPath}/secrets/global/syncthing/N100-03-id.age";
    "secrets/global/ssh/authorized_keys.age".file = "${secretsPath}/secrets/global/ssh/authorized_keys.age";
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 5d";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;
    }
  ];

  services.rpcbind.enable = true;
  systemd.mounts = [{
    type = "nfs";
    mountConfig = {
      Options = "noatime";
    };
    what = "192.168.0.92:/storage";
    where = "/mnt/storage";
  }];

  systemd.automounts = [{
    wantedBy = [ "multi-user.target" ];
    automountConfig = {
      TimeoutIdleSec = "600";
    };
    where = "/mnt/storage";
  }];

  networking.hostName = "n100-01";
  networking.networkmanager.enable = true;
  networking.hosts = {
    "127.0.0.1" = [ "localhost" "${config.networking.hostName}" ];
  };


  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    enableNvidia = false;
  };
  virtualisation.incus.enable = true;
  virtualisation.vswitch.enable = true;
  virtualisation.libvirtd.enable = true;


  programs.appimage.binfmt = true;
  programs.appimage.enable = true;

  time.timeZone = "America/Phoenix";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
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

  # Syncthing
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
        password = "password";
      };
      devices = {
        "DarkStarMk6Mod1" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/DarkStarMk6Mod1-id.age".file;
        };
        "Alienware15R4" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/Alienware15R4-id.age".file;
        };
        "N100-01" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-01-id.age".file;
        };
        "N100-02" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-02-id.age".file;
        };
        "N100-03" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-03-id.age".file;
        };
      };
      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [ "DarkStarMk6Mod1" "Alienware15R4" "N100-01" "N100-02" "N100-03" ];
          label = "Projects";
          enable = false;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [ "DarkStarMk6Mod1" "Alienware15R4" "N100-01" "N100-02" "N100-03" ];
          label = "Documents";
          enable = false;
        };
      };
    };
  };

  # GUI Related Services (Currently Disabled)
  # =======================================
  # services.xrdp = {
  #   enable = true;
  #   defaultWindowManager = "${pkgs.gnome.gnome-session}/bin/gnome-session";
  # };

  # services.xserver = {
  #   enable = true;
  #   layout = "us";
  #   xkbVariant = "";
  #   displayManager = {
  #     gdm.enable = true;
  #     # autoLogin = {
  #     #   enable = true;
  #     #   user = "jamesbrink";
  #     # };
  #   };
  #   desktopManager.gnome.enable = true;
  # };

  # services.printing.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      LoginGraceTime = 0;
      AuthorizedKeysCommand = "${pkgs.bash}/bin/bash -c 'cat ${config.age.secrets."secrets/global/ssh/authorized_keys.age".path}'";
      AuthorizedKeysCommandUser = "root";
    };
  };

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # #####
  # Users
  # #####
  programs.zsh.enable = true;
  programs.mosh.enable = true;
  programs.zsh.autosuggestions.enable = true;
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];

  environment.variables = {
    EDITOR = "vim";
    OLLAMA_HOST = "desktop2";
  };

  users.users.jamesbrink = {
    isNormalUser = true;
    description = "James Brink";
    extraGroups = [ "networkmanager" "wheel" "docker" "qemu-libvirtd" "libvirtd" "incus-admin" ];
    shell = pkgs.zsh;
    useDefaultShell = true;
    packages = with pkgs; [ ];
  };

  home-manager.users.jamesbrink = { pkgs, ... }: {
    programs.starship = {
      enable = true;
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "thefuck" ];
        theme = "robbyrussell";
      };
      shellAliases = {
        ll = "ls -l";
        update = "sudo nixos-rebuild switch --flake /etc/nixos/#default";
        cleanup = "sudo nix-collect-garbage -d";
      };
      history.size = 100000;
    };
    home.stateVersion = "24.05";
  };

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

  programs.neovim = {
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

  nixpkgs.config.allowUnfree = true;
  programs.firefox.enable = true;
  networking.firewall.enable = false;
  system.stateVersion = "24.05";
}
