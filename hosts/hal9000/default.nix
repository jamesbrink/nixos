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
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
    (import ../../users/regular/jamesbrink.nix {
      inherit (args) config pkgs inputs;
      unstablePkgs = pkgs.unstablePkgs;
      inherit (args.inputs) claude-desktop;
    })
    ../../profiles/desktop/default-stable.nix
    ../../profiles/keychron/default.nix
    (import "${args.inputs.nixos-unstable}/nixos/modules/services/misc/ollama.nix")
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  # services.keychron-keyboard = {
  #   enable = true;
  #   user = "jamesbrink";
  # };

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

  boot = {
    kernelParams = [
      "audit=1"
      "zfs.zfs_arc_max=17179869184"
      "zfs.zfs_txg_timeout=5" # Faster transaction group commits
    ];
    kernel.sysctl."kernel.dmesg_restrict" = 0;
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = false;

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelModules = [
      "kvm-intel"
      "kvm-amd"
      "audit"
    ];
    extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.pulseaudio.enable = false;

  # Enable NVIDIA CUDA and OpenCL support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;
    }
  ];

  # Create mount points with appropriate permissions
  systemd.tmpfiles.rules = [
    "d /mnt 0775 root users"
    "d /mnt/storage-fast 0775 root users"
    "d /mnt/storage 0775 root users"
    "d /var/lib/libvirt/images 0775 root libvirtd"
    "d /mnt/storage-fast/quantierra 0755 root root"
    "d /mnt/storage-fast/Steam 0755 jamesbrink users"
    "d ${config.users.users.jamesbrink.home}/.local/share/rustdesk 0755 jamesbrink users"
  ];

  fileSystems."/mnt/storage-fast" = {
    device = "storage-fast";
    fsType = "zfs";
    neededForBoot = true;
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    zed = {
      enableMail = false;
      settings = {
        ZED_DEBUG_LOG = "off";
        ZED_NOTIFY_VERBOSE = "1";
      };
    };
  };

  fileSystems."/mnt/storage-fast/AI" = {
    device = "storage-fast/AI";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/mnt/storage-fast/quantierra" = {
    device = "storage-fast/quantierra";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  systemd.services.zfs-quantierra-setup = {
    description = "Configure ZFS properties for quantierra dataset";
    after = [ "zfs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      /run/current-system/sw/bin/zfs set recordsize=8K storage-fast/quantierra
      /run/current-system/sw/bin/zfs set logbias=throughput storage-fast/quantierra
      /run/current-system/sw/bin/zfs set primarycache=all storage-fast/quantierra
    '';
  };

  fileSystems."/mnt/storage-fast/Steam" = {
    device = "storage-fast/Steam";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/home/jamesbrink/AI" = {
    device = "/mnt/storage-fast/AI";
    options = [ "bind" ];
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

  fileSystems."/export/storage-fast" = {
    device = "/mnt/storage-fast";
    options = [ "bind" ];
  };

  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export                 10.70.100.0/24(rw,fsid=0,no_subtree_check) 100.64.0.0/10(rw,fsid=0,no_subtree_check)
    /export/storage-fast    10.70.100.0/24(rw,nohide,insecure,no_subtree_check) 100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
  '';

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
    hostId = "e71a3d67";
    nftables = {
      enable = true;
    };
    search = [
      "home.urandom.io"
      "urandom.io"
    ];

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

    # Add explicit firewall rules
    firewall = {
      enable = false;
      allowedTCPPorts = [
        22
        3389
      ];
      interfaces = {
        br0 = {
          allowedTCPPorts = [
            22
            3389
          ];
        };
      };
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
        domains = [
          "home.urandom.io"
          "urandom.io"
        ];
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
        AuthorizedKeysCommand = "${pkgs.bash}/bin/bash -c 'cat ${
          config.age.secrets."secrets/global/ssh/authorized_keys.age".path
        }'";
        AuthorizedKeysCommandUser = "root";
      };
    };
  };

  services.rustdesk-server = {
    enable = false;
    openFirewall = true;
    signal.relayHosts = [ "home.urandom.io" ];
  };

  services.timesyncd = {
    enable = true;
    servers = [
      "time.cloudflare.com"
      "time.google.com"
      "pool.ntp.org"
    ];
  };

  systemd.user.services.rustdesk = {
    description = "RustDesk Remote Desktop Client";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "${config.users.users.jamesbrink.home}/.Xauthority";
      XDG_RUNTIME_DIR = "/run/user/1001";
      RUSTDESK_DISPLAY_BACKEND = "x11";
      WAYLAND_DISPLAY = "wayland-0";
      GNOME_SETUP_DISPLAY = ":1";
    };
    serviceConfig = {
      Type = "simple";
      ExecStartPre = [
        "-${pkgs.procps}/bin/pkill -u jamesbrink rustdesk"
        "${pkgs.bash}/bin/bash -c 'until ${pkgs.iproute2}/bin/ip route | grep -q ^default; do sleep 1; done'"
      ];
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.rustdesk}/bin/rustdesk --service --elevate --log-level trace --password \"$(cat ${
        config.age.secrets."secrets/hal9000/rustdesk.age".path
      })\"'";
      RuntimeDirectory = "rustdesk";
      LogsDirectory = "rustdesk";
      StandardOutput = "append:${config.users.users.jamesbrink.home}/.local/share/rustdesk/rustdesk.log";
      StandardError = "append:${config.users.users.jamesbrink.home}/.local/share/rustdesk/rustdesk.err";
      Restart = "always";
      RestartSec = "3s";
      KillMode = "process";
      RestartPreventExitStatus = "SIGKILL";
    };
  };

  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;

  # services.displayManager.autoLogin.enable = true;
  # services.displayManager.autoLogin.user = "jamesbrink";

  # systemd.user.services.sunshine = {
  #   description = "Sunshine self-hosted game stream host for Moonlight";
  #   startLimitBurst = 5;
  #   startLimitIntervalSec = 500;
  #   serviceConfig = {
  #     ExecStart = "${config.security.wrapperDir}/sunshine";
  #     Restart = "on-failure";
  #     RestartSec = "5s";
  #   };
  # };

  # security.wrappers.sunshine = {
  #   owner = "root";
  #   group = "root";
  #   capabilities = "cap_sys_admin+p";
  #   source = "${pkgs.sunshine}/bin/sunshine";
  # };

  services.ollama = {
    enable = false;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";
    package = pkgs.unstablePkgs.ollama-cuda;
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
      "secrets/hal9000/tailscale.age".file = "${secretsPath}/secrets/hal9000/tailscale.age";
      "secrets/hal9000/rustdesk.age" = {
        file = "${secretsPath}/secrets/hal9000/rustdesk.age";
        owner = "jamesbrink";
        group = "users";
        mode = "0400";
      };
    };
  };

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
      # enableNvidia = true;
    };
    oci-containers = {
      containers = {
        postgis = {
          image = "postgis/postgis:13-3.5";
          environment = {
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "postgres";
          };
          volumes = [
            "/mnt/storage-fast/quantierra:/var/lib/postgresql/data"
          ];
          ports = [
            "5432:5432"
          ];
        };
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
          image = "jamesbrink/comfyui:v0.3.14";
          volumes = [
            "/home/jamesbrink/AI/ComfyUI:/comfyui"
            "/home/jamesbrink/AI/ComfyUI-User-Data:/comfyui/user"
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
          environment = {
            PUID = "${toString config.users.users.jamesbrink.uid}";
            PGID = "${toString config.users.users.jamesbrink.group}";
          };
          autoStart = true;
        };

        fooocus = {
          image = "jamesbrink/fooocus:latest";
          volumes = [
            "/home/jamesbrink/AI/Models/StableDiffusion:/fooocus/models"
            "/home/jamesbrink/AI/Output:/fooocus/output"
          ];
          extraOptions = [
            "--gpus=all"
            "--network=host"
            "--name=fooocus"
            "--user=${toString config.users.users.jamesbrink.uid}:${toString config.users.users.jamesbrink.group}"
          ];
          autoStart = false;
        };

        open-webui = {
          image = "ghcr.io/open-webui/open-webui:main";
          volumes = [
            "open-webui:/app/backend/data"
          ];
          ports = [
            "3000:8080"
          ];
          extraOptions = [
            "--add-host=host.docker.internal:host-gateway"
            "--name=open-webui"
          ];
          autoStart = true;
        };

        pipelines = {
          image = "ghcr.io/open-webui/pipelines:main";
          volumes = [
            "pipelines:/app/pipelines"
          ];
          ports = [
            "9099:9099"
          ];
          extraOptions = [
            "--add-host=host.docker.internal:host-gateway"
            "--name=pipelines"
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
              "security.nesting" = "true";
              "security.privileged" = "true";
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

  # Keep OpenWebUI, Pipelines, Fooocus, ComfyUI and Ollama up to date
  systemd.services.update-ai-containers = {
    description = "Update AI container images";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeScript "update-ai-containers" ''
        #!${pkgs.bash}/bin/bash
        ${pkgs.podman}/bin/podman pull ghcr.io/open-webui/open-webui:main
        ${pkgs.podman}/bin/podman pull ghcr.io/open-webui/pipelines:main
        # ${pkgs.podman}/bin/podman pull jamesbrink/fooocus:latest
        # ${pkgs.podman}/bin/podman pull jamesbrink/comfyui:latest
        ${pkgs.podman}/bin/podman pull ollama/ollama

        # Restart containers to use new images
        ${pkgs.systemd}/bin/systemctl restart podman-ollama
        # ${pkgs.systemd}/bin/systemctl restart podman-comfyui
        # ${pkgs.systemd}/bin/systemctl restart podman-fooocus
        ${pkgs.systemd}/bin/systemctl restart podman-open-webui
        ${pkgs.systemd}/bin/systemctl restart podman-pipelines
      '';
    };
  };

  # Add a timer to run it daily
  systemd.timers.update-ai-containers = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  # Create the default network configuration for libvirt
  systemd.services.libvirtd-network-bridge = {
    enable = true;
    description = "Libvirt Network Setup";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    path = [ pkgs.libvirt ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
    };
    script = ''
      # Define the bridge network if it doesn't exist
      virsh net-list --all | grep -q bridge-network || virsh net-define ${pkgs.writeText "bridge-network.xml" ''
        <network>
          <name>bridge-network</name>
          <forward mode="bridge"/>
          <bridge name="br0"/>
        </network>
      ''}

      # Enable bridge network
      virsh net-list --all | grep -q "bridge-network.*inactive" && virsh net-start bridge-network
      virsh net-autostart bridge-network

      # Ensure default network is defined and running
      virsh net-list --all | grep -q default || virsh net-define ${pkgs.writeText "default-network.xml" ''
        <network>
          <name>default</name>
          <forward mode="nat"/>
          <bridge name="virbr0" stp="on" delay="0"/>
          <ip address="192.168.122.1" netmask="255.255.255.0">
            <dhcp>
              <range start="192.168.122.2" end="192.168.122.254"/>
            </dhcp>
          </ip>
        </network>
      ''}

      # Enable default network
      virsh net-list --all | grep -q "default.*inactive" && virsh net-start default
      virsh net-autostart default
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

  # Allow user to bind to privileged ports
  systemd.user.extraConfig = ''
    DefaultCapabilityBoundingSet=CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_BIND_SERVICE
  '';

  # Grant capabilities to the user for direct process execution
  security.wrappers.capability-port-80 = {
    owner = "jamesbrink";
    group = "users";
    capabilities = "cap_net_bind_service+eip";
    source = "${pkgs.bash}/bin/bash";
  };

  # Set user capabilities via pam_cap
  security.pam.services.login.setEnvironment = true;
  environment.etc."security/capability.conf".text = ''
    cap_net_bind_service   jamesbrink
  '';

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
    bottles
    bridge-utils
    distrobox
    dotnetPackages.Nuget
    # unstablePkgs.exo
    exo
    glxinfo
    incus
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    OVMF
    podman
    samba4Full
    spice
    spice-gtk
    spice-protocol
    steam
    sunshine
    unstablePkgs.goose-cli
    unstablePkgs.ollama-cuda
    virt-viewer
    vulkan-tools
    winetricks
    wineWowPackages.waylandFull
    xorriso
  ];

  system.stateVersion = "24.11";

  systemd.services.systemd-networkd-wait-online = {
    serviceConfig = {
      ExecStart = [
        ""
        "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --any"
      ];
    };
  };

  # Add this section for SPICE configuration
  services.spice-vdagentd.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    protontricks.enable = true;
  };

  services.resolved = {
    enable = true;
    fallbackDns = [ ]; # This disables all fallback DNS servers
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "${config.age.secrets."secrets/hal9000/tailscale.age".path}";
  };
}
