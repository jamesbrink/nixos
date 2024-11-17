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
    kernelParams = [ "audit=1" ];
    kernel.sysctl."kernel.dmesg_restrict" = 0;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';
  };

  hardware.pulseaudio.enable = false;

  swapDevices = [{
    device = "/var/swapfile";
    size = 32768;
  }];

  # Create mount points with appropriate permissions
  systemd.tmpfiles.rules = [
    "d /mnt 0775 root users"
    "d /mnt/storage-fast 0775 root users"
    "d /mnt/storage 0775 root users"
    "d /var/lib/libvirt/images 0775 root libvirtd"
  ];

  fileSystems."/mnt/storage-fast" = {
    device = "/dev/disk/by-uuid/7f4b7db5-b6e3-4874-a4e9-52ca0f48576f";
    fsType = "ext4";
    options = [
      "rw"
      "noatime"
      "nofail"
    ];
  };

  fileSystems."/mnt/storage" = {
    device = "alienware.home.urandom.io:/storage";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nofail"
      "x-systemd.automount"
    ];
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
    useNetworkd = true;
    useDHCP = false;
    nftables.enable = true;

    # Configure the bridge
    bridges = {
      br0 = {
        interfaces = [ "enp6s0" ];
      };
    };
    # Configure interfaces
    interfaces = {
      br0.useDHCP = true;
      enp6s0.useDHCP = false;
    };
  };

  # systemd-networkd configuration
  systemd.network = {
    enable = true;
    networks = {
      "10-br0" = {
        matchConfig = {
          Name = "br0";
        };
        networkConfig = {
          DHCP = "ipv4";
        };
        linkConfig = {
          Promiscuous = "yes";
          MACAddress = "a0:36:bc:e7:65:b8";
        };
      };
      "20-enp6s0" = {
        matchConfig = {
          Name = "enp6s0";
        };
        networkConfig = {
          Bridge = "br0";
        };
        linkConfig = {
          Promiscuous = "yes";
        };
      };
    };
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

  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    relayIP = "home.urandom.io";
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

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
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
    incus = {
      enable = true;
      preseed = {
        profiles = [
          {
            name = "nfs-kvm";
            config = {
              "security.nesting" = "true"; # Required for NFS
              "security.privileged" = "true"; # Required for KVM
            };
            devices = {
              eth0 = {
                name = "eth0";
                nictype = "bridged";
                parent = "br0";
                type = "nic";
              };
              kvm = {
                type = "unix-char";
                path = "/dev/kvm";
              };
            };
          }
        ];
      };
    };

    vswitch.enable = true;

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
      onBoot = "ignore";
      onShutdown = "shutdown";
      allowedBridges = [
        "virbr0"
        "br0"
      ];
    };
  };

  # Create the default network configuration for libvirt
  systemd.services.libvirtd-network-bridge = {
    enable = true;
    description = "Libvirt Bridge Network Setup";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    path = [ pkgs.libvirt ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
    };
    script = ''
      # Define the network if it doesn't exist
      virsh net-list --all | grep -q bridge-network || virsh net-define ${pkgs.writeText "bridge-network.xml" ''
        <network>
          <name>bridge-network</name>
          <forward mode="bridge"/>
          <bridge name="br0"/>
        </network>
      ''}
      # Set as default network
      virsh net-list --all | grep -q bridge-network || virsh net-autostart bridge-network
      virsh net-list --all | grep -q bridge-network || virsh net-start bridge-network
      # Set as default network if not already set
      current_default=$(virsh net-info default 2>/dev/null | grep -q "Active.*yes" && echo "yes" || echo "no")
      if [ "$current_default" = "yes" ]; then
        virsh net-destroy default || true
        virsh net-undefine default || true
      fi
    '';
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

  programs.virt-manager.enable = true;
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
    audit
    bridge-utils
    glxinfo
    incus
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    OVMF
    python311Packages.huggingface-hub
    spice
    spice-gtk
    spice-protocol
    sunshine
    unstablePkgs.ollama-cuda
    virt-viewer
    vulkan-tools
    xorriso
  ];

  system.stateVersion = "24.05";

  systemd.services.systemd-networkd-wait-online = {
    serviceConfig = {
      ExecStart = [ "" "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --any" ];
    };
  };

  # Add this section for SPICE configuration
  services.spice-vdagentd.enable = true;
}

