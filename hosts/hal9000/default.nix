{ config, pkgs, lib, secretsPath, inputs, self, ... } @args:

{
  disabledModules = [
    "services/misc/ollama.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
    ../../users/regular/jamesbrink.nix
    ../../profiles/desktop/default-stable.nix
    (import "${args.inputs.nixos-unstable}/nixos/modules/services/misc/ollama.nix")
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
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

  hardware.pulseaudio.enable = false;

  swapDevices = [{
    device = "/var/swapfile";
    size = 32768;
  }];

  fileSystems."/mnt/storage-fast" = {
    device = "/dev/disk/by-uuid/7f4b7db5-b6e3-4874-a4e9-52ca0f48576f";
    fsType = "ext4";
    options = [ "users" "nofail" ];
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  networking = {
    hostName = "hal9000";
    domain = "home.urandom.io";
    networkmanager.enable = true;
    hosts = {
      "127.0.0.1" = [ "localhost" "${config.networking.hostName}" ];
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
        AuthorizedKeysCommand = "${pkgs.bash}/bin/bash -c 'cat ${config.age.secrets."secrets/global/ssh/authorized_keys.age".path}'";
        AuthorizedKeysCommandUser = "root";
      };
    };
  };

  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";
    package = pkgs.unstablePkgs.ollama-cuda;
    # package = self.packages.x86_64-linux.ollama-cuda;
  };

  systemd.mounts = [{
    type = "nfs";
    mountConfig.Options = "noatime";
    what = "alienware.home.urandom.io:/storage";
    where = "/mnt/storage";
  }];

  systemd.automounts = [{
    wantedBy = [ "multi-user.target" ];
    automountConfig.TimeoutIdleSec = "600";
    where = "/mnt/storage";
  }];

  security.rtkit.enable = true;

  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    secrets = {
      "secrets/global/ssh/authorized_keys.age".file = "${secretsPath}/secrets/global/ssh/authorized_keys.age";
    };
  };

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      enableNvidia = true;
    };
    oci-containers = {
      backend = "docker";
      containers = {
        ollama = {
          image = "ollama/ollama";
          volumes = [
            "/var/lib/private/ollama:/root/.ollama"
          ];
          ports = [
            "11434:11434"
          ];
          autoStart = true;
          extraOptions = [
            "--gpus=all"
            "--name=ollama"
          ];
        };

        comfyui = {
          image = "jamesbrink/comfyui";
          volumes = [
            "/home/jamesbrink/AI/ComfyUI:/comfyui"
            "/home/jamesbrink/AI/Models/StableDiffusion:/comfyui/models"
            "/home/jamesbrink/AI/Output:/comfyui/output"
            "/home/jamesbrink/AI/Input:/comfyui/input"
          ];
          extraOptions = [
            "--gpus=all"
            "--network=host"
            "--name=comfyui"
            "--user=${toString config.users.users.jamesbrink.uid}:${toString config.users.users.jamesbrink.group}"
          ];
          cmd = [
            "--listen"
            "--port"
            "8190"
            "--preview-method"
            "auto"
          ];
          autoStart = true;
        };
      };
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

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  services.xserver = {
    videoDrivers = [ "nvidia" ];
    screenSection = ''
      Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option "AllowIndirectGLXProtocol" "off"
      Option "TripleBuffer" "on"
    '';
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = false;
    };
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime.sync.enable = false;
  };

  environment = {
    shells = with pkgs; [ zsh ];
    variables = {
      EDITOR = "vim";
      OLLAMA_HOST = "hal9000";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
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

  environment.systemPackages = with pkgs; [
    glxinfo
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    python311Packages.huggingface-hub
    unstablePkgs.ollama-cuda
    vulkan-tools
  ];

  system.stateVersion = "24.05";
}

