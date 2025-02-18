{ config
, pkgs
, lib
, secretsPath
, inputs
, self
, ...
}@args:

{
  disabledModules = [
    "services/misc/ollama.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
    (import ../../users/regular/jamesbrink.nix { inherit (args) config pkgs inputs unstablePkgs; inherit (args.inputs) claude-desktop; })
    ../../profiles/desktop/default-stable.nix
    (import "${args.inputs.nixos-unstable}/nixos/modules/services/misc/ollama.nix")
  ];

  security.audit.enable = true;
  security.auditd.enable = true;
  security.audit.failureMode = "printk";
  security.audit.rules = [
    "-a exit,always -F arch=b64 -S execve"
    "-w /etc/passwd -p wa -k passwd_changes"
    "-w /etc/shadow -p wa -k shadow_changes"
    "-w /var/log/audit/ -p wa -k audit_logs"
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

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;

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

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export           10.70.100.0/24(rw,fsid=0,no_subtree_check)
    /export/storage   10.70.100.0/24(rw,nohide,insecure,no_subtree_check)
    /export/data      10.70.100.0/24(rw,nohide,insecure,no_subtree_check)
  '';

  networking.hostName = "Alienware15R4";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

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

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Phoenix";

  # Select internationalisation properties.
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;

  # hardware.opengl = {
  #   enable = true;
  #   driSupport = true;
  #   driSupport32Bit = true;
  # };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia.prime = {
    # sync.enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

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

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # services.vscode-server.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
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
          # enable = true;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [
            "DarkStarMk6Mod1"
            "Alienware15R4"
          ];
          label = "Documents";
          # enable = true;
        };
      };
    };
  };

  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];

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

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };
  # services.openvswitch.enable = true;
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    enableNvidia = true;
  };
  virtualisation.vmware.guest.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.vswitch.enable = true;
  virtualisation.libvirtd.enable = true;

  services.xrdp.enable = true;
  services.xrdp.openFirewall = true;
  services.xrdp.defaultWindowManager = "${pkgs.gnome.gnome-session}/bin/gnome-session";
  services.gnome.gnome-remote-desktop.enable = true;
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

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.tailscale.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.darling.enable = true;
  programs.zsh.enable = true;
  programs.zsh.autosuggestions.enable = true;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # pixinsight
    alacritty
    alacritty-theme
    ansible
    at
    autorestic
    awscli2
    bitwarden
    bitwarden-cli
    blender
    bzip2
    cachix
    certbot
    chromium
    circleci-cli
    cmake
    cudaPackages.cudatoolkit
    cw
    darling
    darling-dmg
    dig
    direnv
    dnsutils
    docker
    exo
    fd
    file
    fira-code-nerdfont
    fly
    gcc
    gimp
    git
    git-crypt
    git-secrets
    git-secrets
    gitea
    gitlab
    gnome.gnome-session
    gnumake
    gparted
    hdparm
    headscale
    hfsprogs
    home-manager
    htop
    iperf2
    ipmitool
    jdk
    jq
    k3s
    k6
    kind
    kops
    kubectl
    kubectx
    lego
    lf
    libxisf
    lshw
    mkdocs
    mtr
    mtr-gui
    neofetch
    neovim
    nerdfonts
    netcat
    nfs-utils
    nixpkgs-fmt
    nodejs
    nodenv
    nushellFull
    nvtopPackages.nvidia
    open-vm-tools
    openssh
    opentofu
    openvswitch
    packer
    packer
    parted
    pre-commit
    pyenv
    python3
    python311Packages.boto3
    python311Packages.pip
    python311Packages.pynvim
    restic
    restique
    ripgrep
    rng-tools
    rsync
    rustfmt
    rustup
    screen
    shellcheck
    slack
    slack-cli
    slack-term
    spin
    sshpass
    starship
    steam
    sublime
    sunshine
    tailscale
    terraform-docs
    terraform-lsp
    tflint
    tigervnc
    tmux
    unzip
    vagrant
    vim
    vscode
    vscode-extensions.adpyke.codesnap
    vscode-extensions.twxs.cmake
    wget
    wineWowPackages.full
    wireguard-tools
    xorg.xinit
    xrdp
    zellij
    zfs
    zsh
  ];

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  networking.firewall.allowedTCPPorts = [
    22
    3389
    47984
    47989
    47990
    48010
    7865
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 47998;
      to = 48000;
    }
    {
      from = 8000;
      to = 8010;
    }
  ];
  networking.firewall.enable = false;
  system.stateVersion = "24.11";
}
