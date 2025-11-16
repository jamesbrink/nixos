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
    # ./nginx.nix # Disabled - keeping only postgres13 and ollama
    # ./nginx-netboot.nix # Disabled - keeping only postgres13 and ollama
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/shared-packages/devops.nix
    ../../modules/restic-backups.nix
    ../../users/regular/jamesbrink.nix
    # ../../users/regular/strivedi.nix # Temporarily disabled for UID migration
    ../../profiles/desktop/hyprland.nix
    ../../profiles/keychron/default.nix
    # ../../modules/services/ai-starter-kit/default.nix # Disabled - n8n, qdrant, pipelines
    ../../modules/services/k3s.nix
    ../../modules/services/tftp-server.nix
    ../../modules/services/netboot-configs.nix
    ../../modules/services/netboot-autochain.nix
    ../../modules/services/windows11-vm.nix
    ../../modules/services/samba-server.nix
    # ../../modules/services/netboot-server.nix  # Replaced by tftp-server.nix
    (import "${args.inputs.nixos-unstable}/nixos/modules/services/misc/ollama.nix")
  ];

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "qtwebkit-5.212.0-alpha4"
    ];
  };

  # Home-manager configuration
  home-manager.backupFileExtension = "backup";

  # services.keychron-keyboard = {
  #   enable = true;
  #   user = "jamesbrink";
  # };

  security.audit.enable = false;
  security.auditd.enable = false;
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
      systemd-boot.configurationLimit = 3;
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
  services.pulseaudio.enable = false;

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
    "d /export 0755 root root"
    "d /mnt 0775 root users"
    "d /storage-fast 0775 root users"
    "d /mnt/storage 0775 root users"
    "d /mnt/storage20tb 0775 root users"
    "d /export/storage20tb 0755 root root"
    "d /var/lib/libvirt/images 0775 root libvirtd"
    "d /storage-fast/vms 0775 jamesbrink libvirtd"
    "d ${config.users.users.jamesbrink.home}/.local/share/rustdesk 0755 jamesbrink users"
    # PixInsight cache directory - prevents garbage collection of the tar.xz file
    "d /var/cache/pixinsight 0755 root root"
  ];

  fileSystems."/storage-fast" = {
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

  fileSystems."/storage-fast/AI" = {
    device = "storage-fast/AI";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/storage-fast/quantierra" = {
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

  fileSystems."/storage-fast/Steam" = {
    device = "storage-fast/Steam";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/storage-fast/n8n" = {
    device = "storage-fast/n8n";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/storage-fast/ollama" = {
    device = "storage-fast/ollama";
    fsType = "zfs";
    options = [
      "zfsutil"
      "X-mount.mkdir"
    ];
  };

  fileSystems."/home/jamesbrink/AI" = {
    device = "/storage-fast/AI";
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
    device = "/storage-fast";
    options = [ "bind" ];
  };

  # New 20TB storage drive
  fileSystems."/mnt/storage20tb" = {
    device = "/dev/disk/by-uuid/6d016e74-3cff-4f4d-8a8a-2769e7f35d76";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/export/storage20tb" = {
    device = "/mnt/storage20tb";
    options = [ "bind" ];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export                 10.70.100.0/24(rw,fsid=0,no_subtree_check) 100.64.0.0/10(rw,fsid=0,no_subtree_check)
      /export/storage-fast    10.70.100.0/24(rw,nohide,insecure,no_subtree_check) 100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
      /export/storage20tb     10.70.100.0/24(rw,nohide,insecure,no_subtree_check) 100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
    '';
    # Ensure NFS listens on all interfaces
    lockdPort = 4045;
    mountdPort = 4046;
    statdPort = 4047;
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # PostgreSQL WAL sync service
  systemd.services.postgresql-wal-sync = {
    description = "Sync PostgreSQL WAL files from Quantierra server";
    # Enable WAL sync to catch up on replication lag
    enable = true;
    serviceConfig = {
      Type = "oneshot";
      # Run as root since we need to manage permissions and ZFS snapshots
      User = "root";
      Group = "root";
      # Use the full sync script with retention management
      ExecStart = "/run/current-system/sw/bin/postgres13-wal-sync-full";
      # Logging
      StandardOutput = "journal";
      StandardError = "journal";
    };
    # Ensure the service can access network
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # Timer for nightly execution
  systemd.timers.postgresql-wal-sync = {
    description = "Run PostgreSQL WAL sync nightly";
    # Enable timer for automatic WAL sync
    enable = true;
    timerConfig = {
      # Run at 3 AM every day
      OnCalendar = "daily";
      AccuracySec = "1h";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  # Service for creating base snapshots
  systemd.services.postgresql-base-snapshot = {
    description = "Create PostgreSQL base snapshot for reset operations";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = "/run/current-system/sw/bin/postgres13-create-base-auto";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    after = [ "postgresql-wal-sync.service" ];
  };

  # Timer for base snapshot creation every 3 days
  systemd.timers.postgresql-base-snapshot = {
    description = "Create PostgreSQL base snapshot every 3 days";
    enable = true;
    timerConfig = {
      # Run every 3 days at 4 AM
      OnCalendar = "*-*-1,4,7,10,13,16,19,22,25,28,31 04:00:00";
      AccuracySec = "1h";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

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
      enable = true;
      # Trust all traffic from Tailscale interface
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [
        22
        80 # HTTP
        443 # HTTPS
        111 # RPC portmapper
        2049 # NFS
        4045 # NFS lockd
        4046 # NFS mountd
        4047 # NFS statd
        139 # NetBIOS Session Service
        445 # SMB/CIFS
        3389
        5439 # PostgreSQL 13 dev database (PostGIS)
        5900 # SPICE for VMs
        5901 # Additional SPICE ports
        5902
        5903
        5904
        7000 # AirPlay
        7001 # AirPlay
        7100 # AirPlay screen mirroring
        7865 # Fooocus web UI
        # Development ports
        3000
        3001
        3002
        3003
        3004
        3005
        3006
        3007
        3008
        3009
        3010
        8000
        8001
        8002
        8003
        8004
        8005
        8006
        8007
        8008
        8009
        8010
      ];
      allowedUDPPorts = [
        111 # RPC portmapper
        137 # NetBIOS Name Service
        138 # NetBIOS Datagram Service
        2049 # NFS
        4045 # NFS lockd
        4046 # NFS mountd
        4047 # NFS statd
        5353 # mDNS/Bonjour for macOS discovery
        6000 # AirPlay screen mirroring
        6001 # AirPlay screen mirroring
        7000 # AirPlay
        7001 # AirPlay
        7011 # AirPlay control
      ];
      interfaces = {
        br0 = {
          allowedTCPPorts = [
            22
            111 # RPC portmapper
            139 # NetBIOS Session Service
            445 # SMB/CIFS
            2049 # NFS
            4045 # NFS lockd
            4046 # NFS mountd
            4047 # NFS statd
            3389
            5439 # PostgreSQL 13 dev database (PostGIS)
            7000 # AirPlay
            7001 # AirPlay
            7100 # AirPlay screen mirroring
            # Development ports
            3000
            3001
            3002
            3003
            3004
            3005
            3006
            3007
            3008
            3009
            3010
          ];
          allowedUDPPorts = [
            111 # RPC portmapper
            137 # NetBIOS Name Service
            138 # NetBIOS Datagram Service
            2049 # NFS
            4045 # NFS lockd
            4046 # NFS mountd
            4047 # NFS statd
            5353 # mDNS/Bonjour for macOS discovery
            6000 # AirPlay screen mirroring
            6001 # AirPlay screen mirroring
            7000 # AirPlay
            7001 # AirPlay
            7011 # AirPlay control
          ];
        };
      };
      # Allow all traffic from local 10.x network (nftables rules)
      extraInputRules = ''
        ip saddr 10.0.0.0/8 counter accept comment "Accept all from local 10.x network"
      '';
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

  # Prevent network services from restarting during deployment to avoid SSH disconnection
  systemd.services.systemd-networkd.restartIfChanged = false;
  systemd.services.systemd-resolved.restartIfChanged = false;

  services = {
    rpcbind.enable = true;
    printing.enable = true;
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
      XDG_RUNTIME_DIR = "/run/user/${toString config.users.users.jamesbrink.uid}";
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
        config.age.secrets."hal9000-rustdesk".path
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

  security.rtkit.enable = true;

  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    secrets = {
      "global-ssh-authorized-keys" = {
        file = "${secretsPath}/global/ssh/authorized_keys.age";
      };
      "hal9000-tailscale" = {
        file = "${secretsPath}/hal9000/tailscale.age";
      };
      "hal9000-rustdesk" = {
        file = "${secretsPath}/hal9000/rustdesk.age";
        owner = "jamesbrink";
        group = "users";
        mode = "0400";
      };
      "k3s-token" = {
        file = "${secretsPath}/hal9000/k3s-token.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "global-aws-cert-credentials" = {
        file = "${secretsPath}/global/aws/cert-credentials-secret.age";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };

  virtualisation = {
    containers = {
      enable = true;
      containersConf.settings = {
        engine = {
          runtime = "crun";
          runtimes = {
            crun = [ "${pkgs.crun}/bin/crun" ];
            runc = [ "${pkgs.runc}/bin/runc" ];
          };
        };
      };
    };
    podman = {
      enable = true;
      dockerCompat = false; # Disable docker compatibility to use real Docker
      defaultNetwork.settings.dns_enabled = true;
      # enableNvidia = true;
      extraPackages = with pkgs; [
        runc
        crun
        conmon
      ];
    };
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      daemon.settings = {
        features = {
          buildkit = true;
        };
      };
    };
    oci-containers = {
      containers = {
        postgres13 = {
          image = "postgis/postgis:13-3.5";
          environment = {
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "postgres";
          };
          volumes = [
            "/storage-fast/quantierra/postgres13:/var/lib/postgresql/data"
            "/storage-fast/quantierra/archive:/var/lib/postgresql/archive:ro"
            "${../../modules/services/postgresql/postgresql.conf}:/etc/postgresql/postgresql.conf:ro"
            "${../../modules/services/postgresql/pg_hba.conf}:/etc/postgresql/pg_hba.conf:ro"
          ];
          cmd = [
            "postgres"
            "-c"
            "config_file=/etc/postgresql/postgresql.conf"
            "-c"
            "hba_file=/etc/postgresql/pg_hba.conf"
          ];
          ports = [
            "5439:5432" # Expose container's 5432 as host's 5439
          ];
        };

        # postgres17 = {
        #   image = "postgis/postgis:17-3.5";
        #   user = "postgres:postgres";
        #   entrypoint = "/usr/lib/postgresql/17/bin/postgres";
        #   environment = {
        #     POSTGRES_USER = "postgres";
        #     POSTGRES_PASSWORD = "postgres";
        #     POSTGRES_HOST_AUTH_METHOD = "trust";
        #     POSTGRES_INITDB_ARGS = "";
        #   };
        #   volumes = [
        #     "/storage-fast/quantierra-dev-17:/var/lib/postgresql/data"
        #     "${../../modules/services/postgresql/postgresql.conf}:/etc/postgresql/postgresql.conf:ro"
        #     "${../../modules/services/postgresql/pg_hba.conf}:/etc/postgresql/pg_hba.conf:ro"
        #   ];
        #   cmd = [
        #     "-D"
        #     "/var/lib/postgresql/data/new"
        #     "-c"
        #     "config_file=/etc/postgresql/postgresql.conf"
        #     "-c"
        #     "hba_file=/etc/postgresql/pg_hba.conf"
        #   ];
        #   ports = [
        #     "5439:5432"
        #   ];
        # };

        ollama = {
          image = "ollama/ollama:latest";
          volumes = [
            "/storage-fast/ollama:/root/.ollama"
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

        # comfyui = {
        #   image = "jamesbrink/comfyui:latest";
        #   volumes = [
        #     "/home/jamesbrink/AI/ComfyUI-User-Data:/data/user:z"
        #     "/home/jamesbrink/AI/Models/StableDiffusion:/data/models:z"
        #     "/home/jamesbrink/AI/Output:/data/output:z"
        #     "/home/jamesbrink/AI/Input:/data/input:z"
        #     "/home/jamesbrink/AI/ComfyUI/custom_nodes:/data/custom_nodes:z"
        #   ];
        #   cmd = [
        #     "--listen"
        #     "--port"
        #     "8188"
        #     "--preview-method"
        #     "auto"
        #   ];
        #   extraOptions = [
        #     "--gpus=all"
        #     "--network=host"
        #     "--name=comfyui"
        #   ];
        #   environment = {
        #     PUID = "${toString config.users.users.jamesbrink.uid}";
        #     PGID = "${toString config.users.groups.users.gid}";
        #   };
        #   ports = [ "8188:8188" ];
        #   autoStart = true;
        # };

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

        # Disabled - keeping only postgres13 and ollama
        # open-webui = {
        #   image = "ghcr.io/open-webui/open-webui:main";
        #   volumes = [
        #     "open-webui:/app/backend/data"
        #   ];
        #   ports = [
        #     "3000:8080"
        #   ];
        #   environment = {
        #     OLLAMA_BASE_URL = "http://hal9000:11434";
        #   };
        #   extraOptions = [
        #     "--add-host=host.docker.internal:host-gateway"
        #     "--name=open-webui"
        #   ];
        #   autoStart = true;
        # };

        # Disabled - keeping only postgres13 and ollama
        # pipelines = {
        #   image = "ghcr.io/open-webui/pipelines:main";
        #   volumes = [
        #     "pipelines:/app/pipelines"
        #   ];
        #   ports = [
        #     "9099:9099"
        #   ];
        #   extraOptions = [
        #     "--add-host=host.docker.internal:host-gateway"
        #     "--name=pipelines"
        #   ];
        #   autoStart = true;
        # };
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

  # Keep Postgres13 and Ollama up to date
  systemd.services.update-ai-containers = {
    description = "Update AI container images";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeScript "update-ai-containers" ''
        #!${pkgs.bash}/bin/bash
        # ${pkgs.podman}/bin/podman pull ghcr.io/open-webui/open-webui:main # Disabled
        # ${pkgs.podman}/bin/podman pull ghcr.io/open-webui/pipelines:main # Disabled
        # ${pkgs.podman}/bin/podman pull jamesbrink/fooocus:latest
        # ${pkgs.podman}/bin/podman pull jamesbrink/comfyui:latest
        ${pkgs.podman}/bin/podman pull ollama/ollama:latest
        ${pkgs.podman}/bin/podman pull postgis/postgis:13-3.5

        # Restart containers to use new images
        ${pkgs.systemd}/bin/systemctl restart podman-ollama
        ${pkgs.systemd}/bin/systemctl restart podman-postgres13
        # ${pkgs.systemd}/bin/systemctl restart podman-comfyui
        # ${pkgs.systemd}/bin/systemctl restart podman-fooocus
        # ${pkgs.systemd}/bin/systemctl restart podman-open-webui # Disabled
        # ${pkgs.systemd}/bin/systemctl restart podman-pipelines # Disabled
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
    ssh = {
      startAgent = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
    mosh.enable = true;
    firefox.enable = true;
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

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
    # IMPORTANT: pixinsight is pinned to a specific version - DO NOT MODIFY
    # This avoids expensive rebuilds. If you need to update, coordinate with jamesbrink
    pixinsight # Pinned via overlay to version 1.9.3-20250402 - using cached file
    # unstablePkgs.exo
    audit
    bottles
    bridge-utils
    distrobox
    websocketd
    dotnetPackages.Nuget
    exo
    glxinfo
    incus
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    OVMF
    pgbackrest
    pgweb
    podman
    podman-compose
    docker-compose
    samba4Full
    spice
    spice-gtk
    spice-protocol
    steam
    sunshine
    unstablePkgs.ollama-cuda
    uxplay
    virt-viewer
    vulkan-tools
    winetricks
    wineWowPackages.waylandFull
    xorriso
    (import ../../modules/packages/postgres13-reset { inherit pkgs; })
    (import ../../modules/packages/postgres13-reset/wal-sync.nix { inherit pkgs; })
    # GStreamer plugins for UxPlay
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
  ];

  system.stateVersion = "25.05";

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
    gamescopeSession.enable = true;
  };

  services.resolved = {
    enable = true;
    fallbackDns = [ ]; # This disables all fallback DNS servers
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "${config.age.secrets."hal9000-tailscale".path}";
  };

  # webhook service configuration
  environment.etc."webhook/hooks.json".text = ''
    [
      {
        "id": "postgres-rollback",
        "trigger-rule": {
          "or": [
            {
              "match": {
                "type": "value",
                "value": "WEBHOOK_TOKEN_RESET",
                "parameter": {
                  "source": "header",
                  "name": "X-Webhook-Token"
                }
              }
            },
            {
              "match": {
                "type": "value",
                "value": "WEBHOOK_TOKEN_RESET17",
                "parameter": {
                  "source": "header",
                  "name": "X-Webhook-Token"
                }
              }
            },
            {
              "match": {
                "type": "value",
                "value": "WEBHOOK_TOKEN_ACTIVE",
                "parameter": {
                  "source": "header",
                  "name": "X-Webhook-Token"
                }
              }
            }
          ]
        },
        "pass-arguments-to-command": [
          {
            "source": "header",
            "name": "X-Webhook-Token"
          }
        ],
        "command-working-directory": "/",
        "execute-command": "/run/current-system/sw/bin/webhook-postgres-reset",
        "response-message": "Database reset completed successfully",
        "include-command-output-in-response": true
      }
    ]
  '';

  systemd.services.webhook = {
    description = "Webhook Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";
      ExecStart = "${pkgs.webhook}/bin/webhook -hooks /etc/webhook/hooks.json -verbose";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # pgweb service configuration
  systemd.services.pgweb = {
    description = "pgweb PostgreSQL database browser";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PGHOST = "127.0.0.1";
      PGUSER = "postgres";
      PGPASSWORD = "postgres";
      PGDATABASE = "nyc_real_estate_dev";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.pgweb}/bin/pgweb --bind=0.0.0.0 --listen=8081 --host=127.0.0.1 --port=5439 --user=postgres --pass=postgres --db=nyc_real_estate_dev --skip-open --sessions";
      Restart = "always";
      RestartSec = "5s";
      User = "jamesbrink";
    };
  };

  # ZFS monitoring websocket service
  # Copy ZFS monitor HTML file
  system.activationScripts.copyZfsMonitorHtml = ''
    mkdir -p /var/www/zfs.home.urandom.io
    cp ${./zfs-monitor.html} /var/www/zfs.home.urandom.io/index.html
    chmod 644 /var/www/zfs.home.urandom.io/index.html
  '';

  systemd.services.zfs-monitor = {
    description = "ZFS monitoring websocket service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.websocketd}/bin/websocketd --port=9999 --address=0.0.0.0 ${pkgs.writeScript "zfs-monitor" ''
        #!${pkgs.bash}/bin/bash
        while true; do
          ${pkgs.zfs}/bin/zfs list 2>/dev/null | ${pkgs.gawk}/bin/awk "NR>1" | ${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.coreutils}/bin/tr "\n" ";" | ${pkgs.gnused}/bin/sed "s/;$//";
          ${pkgs.coreutils}/bin/sync;
          ${pkgs.coreutils}/bin/stdbuf -oL ${pkgs.coreutils}/bin/echo;
          sleep 1;
        done
      ''}";
      Restart = "always";
      RestartSec = "5s";
      User = "root"; # Needed for ZFS commands
    };
  };

  # Disabled - keeping only postgres13 and ollama
  # services.ai-starter-kit = {
  #   enable = true;
  #   storagePath = "/storage-fast/n8n";
  #   n8n = {
  #     enable = true;
  #     editorBaseUrl = "https://n8n.home.urandom.io";
  #     webhookUrl = "https://n8n.home.urandom.io";
  #   };
  #   qdrant.enable = true;
  #   postgres = {
  #     user = "n8n";
  #     password = "n8n"; # You might want to change this
  #     database = "n8n";
  #   };
  # };

  # Enable TFTP server for N100 cluster netboot
  services.tftp-server = {
    enable = true;
    interface = "br0";
  };

  # Enable N100 netboot configuration file generation
  services.netbootConfigs = {
    enable = true;
    nodes = {
      "n100-01" = {
        macAddress = "e0:51:d8:12:ba:97";
        disk = "/dev/nvme0n1";
        zfsPool = "rpool";
        dhcp = true;
      };
      "n100-02" = {
        macAddress = "e0:51:d8:13:04:50";
        disk = "/dev/nvme0n1";
        zfsPool = "rpool";
        dhcp = true;
      };
      "n100-03" = {
        macAddress = "e0:51:d8:13:4e:91";
        disk = "/dev/nvme0n1";
        zfsPool = "rpool";
        dhcp = true;
      };
      "n100-04" = {
        macAddress = "e0:51:d8:15:46:4e";
        disk = "/dev/nvme0n1";
        zfsPool = "rpool";
        dhcp = true;
      };
    };
  };

  # Enable auto-chain script for N100 detection
  services.netboot-autochain = {
    enable = true;
  };

  # Keep nginx serving netboot images on port 8079
  # (configured in nginx.nix)

  # Windows 11 Development VM
  services.windows11-vm = {
    enable = true;
    memory = 16; # 16GB RAM
    vcpus = 12; # 12 vCPUs (6 cores with 2 threads)
    diskSize = "100G";
    diskPath = "/storage-fast/vms/win11-dev.qcow2";
    owner = "jamesbrink";
    autostart = false; # Don't autostart, let user control it
  };

  # K3s Kubernetes cluster with GPU support (master node)
  services.k3s-cluster = {
    enable = true;
    role = "server";
    users = [ "jamesbrink" ];
    admins = [ "jamesbrink" ];
    hostname = "hal9000";
    domain = "home.urandom.io";
    maxPods = 500;
    storagePoolDataset = "storage-fast/k3s";
    storageMountpoint = "/var/lib/rancher";
    enableTraefik = true;
    enableGpuSupport = true;
    certManager = {
      enable = true;
      email = "admin@home.urandom.io";
      server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      route53 = {
        credentialsFile = config.age.secrets."global-aws-cert-credentials".path;
        region = "us-west-2";
        secretName = "route53-credentials";
      };
      traefik = {
        enableDefaultCertificate = true;
        certificateName = "traefik-wildcard-home";
        secretName = "wildcard-home-urandom-io";
        dnsNames = [
          "*.home.urandom.io"
          "home.urandom.io"
          "*.dev.urandom.io"
          "dev.urandom.io"
        ];
      };
    };
  };

  # Samba server configuration - sharing same paths as NFS
  services.samba-server = {
    enable = true;
    workgroup = "WORKGROUP";
    serverString = "HAL9000 Samba Server";
    enableWSDD = true; # Enable Windows 10/11 network discovery

    shares = {
      # Local hal9000 shares only
      export = {
        path = "/export";
        comment = "HAL9000 export root";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
      storage-fast = {
        path = "/storage-fast";
        comment = "Fast storage array";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
      # Add alias without hyphen for macOS compatibility
      storage = {
        path = "/storage-fast";
        comment = "Fast storage array (alias)";
        browseable = true;
        readOnly = false;
        validUsers = [ "jamesbrink" ];
        createMask = "0664";
        directoryMask = "0775";
      };
      storage20tb = {
        path = "/mnt/storage20tb";
        comment = "20TB Storage Drive";
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

  # TODO troubleshoot this
  # UxPlay AirPlay screen mirroring service
  # systemd.services.uxplay = {
  #   description = "UxPlay AirPlay screen mirroring server";
  #   after = [ "network.target" "avahi-daemon.service" ];
  #   requires = [ "avahi-daemon.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.uxplay}/bin/uxplay -n 'HAL9000 Screen' -nh -p";
  #     Restart = "always";
  #     RestartSec = "10s";
  #     User = "jamesbrink";
  #     Group = "users";
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  #   environment = {
  #     DISPLAY = ":0";
  #     HOME = "/home/jamesbrink";
  #     XDG_RUNTIME_DIR = "/run/user/1000";
  #     GST_DEBUG = "3";
  #   };
  # };
}
