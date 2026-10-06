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
  assertions = [
    {
      assertion =
        config.age.secrets != { }
        && lib.all (secret: builtins.pathExists secret.file) (builtins.attrValues config.age.secrets);
      message = "HAL9000 encrypted activation inputs are missing; stage the pinned secrets submodule before building.";
    }
  ];

  disabledModules = [
    "services/misc/ollama.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    # ./nginx.nix
    # ./nginx-netboot.nix
    ../../modules/nix-caches.nix
    ../../modules/nix-limits.nix
    ../../modules/wifi-iwd.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/python.nix
    ../../modules/shared-packages/devops.nix
    ../../users/regular/jamesbrink.nix
    ../../profiles/desktop/hyprland.nix
    ../../profiles/keychron/default.nix
    ../../modules/services/strata
    ../../modules/services/orca-q4
    ../../modules/services/k3s.nix
    ../../modules/services/tftp-server.nix
    ../../modules/services/netboot-configs.nix
    ../../modules/services/netboot-autochain.nix
    ../../modules/services/windows11-vm.nix
    ../../modules/services/samba-server.nix
    ../../modules/services/internal-dns
    ../../modules/services/claude-remote-control.nix
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

  # Audit disabled to prevent kauditd queue overflow
  security.audit.enable = false;
  security.auditd.enable = false;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Allow remote build requests from trusted users
      trusted-users = [
        "root"
        "jamesbrink"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  boot = {
    # Enable aarch64-linux emulation for building ARM Docker images
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    kernelParams = [
      "audit=0"
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
    # Backing store for the GitHub Actions runners in k3s. Both live on
    # /storage-fast (ZFS) rather than the root filesystem, which is ~83% full
    # and also carries the mold server: a runaway build tree there would trip
    # kubelet eviction and take mold down with it.
    #
    # 1001:1001 is the "runner" user inside
    # ghcr.io/jamesbrink/github-runner-full. hostPath mounts ignore fsGroup, so
    # these must already be owned by that uid or every cache write fails.
    "d /storage-fast/k8s-local-path 0755 root root"
    "d /storage-fast/gha-cache 0755 1001 1001"
    "d /storage-fast/gha-cache/cargo 0755 1001 1001"
    "d /storage-fast/gha-cache/sccache 0755 1001 1001"
    "d /storage-fast/gha-cache/bun 0755 1001 1001"
    "d /storage-fast/gha-cache/tools 0755 1001 1001"
    "d /mnt/storage 0775 root users"
    "d /mnt/storage20tb 0775 root users"
    # Dropbox sync folder lives on the 20TB disk, owned by jamesbrink; bind-mounted
    # to ~/Dropbox below so the proprietary client sees its default location.
    "d /mnt/storage20tb/Dropbox 0755 jamesbrink users -"
    "d /export/storage20tb 0755 root root"
    "d /var/lib/libvirt/images 0775 root libvirtd"
    "d /storage-fast/vms 0775 jamesbrink libvirtd"
    "d ${config.users.users.jamesbrink.home}/.local/share/rustdesk 0755 jamesbrink users"
    # PixInsight cache directory - prevents garbage collection of the tar.xz file
    "d /var/cache/pixinsight 0755 root root"
    "d /storage-fast/ollama 0755 ollama ollama -"
    "d /storage-fast/ollama/.ollama 0755 ollama ollama -"
    "d /storage-fast/ollama/models 0755 ollama ollama -"
    # Root-owned so tmpfiles can safely create mold-owned subdirs (avoids unsafe path transition)
    "d /mnt/storage20tb/AI 0755 root root -"
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

  # Bound shutdown time. Units with KillMode=process (docker, libvirtd, incus,
  # lxcfs, nix-daemon) leave children behind that systemd-shutdown waits on for
  # DefaultTimeoutStopSec after the journal is gone; the reboot watchdog
  # hard-resets if the final phase (unmount/zpool sync) wedges. Units with an
  # explicit TimeoutStopSec (postgresql, mold, entropy) keep theirs.
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "30s";
    RebootWatchdogSec = "3min";
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

  # Child datasets (Steam, ollama, mold, postgresql, entropy, k3s, benchmark)
  # are mounted by zfs-mount.service from their native `mountpoint` property.
  # Do NOT also declare them in fileSystems: the fstab mount units and
  # `zfs mount -a` race for the same mountpoints at boot, the loser gets
  # "mountpoint or dataset is busy", and a failed fstab unit drops the box into
  # emergency mode (2026-09-26). Services that need one order after
  # zfs-mount.service instead (see mold and postgresql below).

  fileSystems."/home/jamesbrink/AI" = {
    device = "/mnt/storage20tb/AI";
    options = [
      "bind"
      "x-systemd.requires-mounts-for=/mnt/storage20tb"
    ];
  };

  # Disabled while alienware is offline (unreachable since ~2025-01). The
  # options below are correct — fstab-generated, so nofail and the 20s timeout
  # genuinely apply — but the unit still fails on every switch and lands in
  # `systemctl --failed`. Nothing in the fleet reads /mnt/storage, so the mount
  # is pure noise until the host is back. Re-enable by uncommenting; see the
  # offlineServers list in modules/nfs-mounts.nix for the other alienware/n100
  # shares parked the same way.
  # fileSystems."/mnt/storage" = {
  #   device = "alienware.home.urandom.io:/storage";
  #   fsType = "nfs";
  #   options = [
  #     "rw"
  #     "noatime"
  #     "nofail"
  #     "noauto"
  #     "soft"
  #     "timeo=15"
  #     "retrans=3"
  #     "x-systemd.automount"
  #     "x-systemd.mount-timeout=20s"
  #     "x-systemd.idle-timeout=600"
  #   ];
  # };

  fileSystems."/export/storage-fast" = {
    device = "/storage-fast";
    options = [
      "rbind"
      # Bind after the child datasets are mounted so the export sees them.
      "x-systemd.after=zfs-mount.service"
    ];
  };

  # New 20TB storage drive. noatime: this disk holds many files served over
  # NFS/Samba/Dropbox; dropping atime write-back removes a metadata write on
  # every read. (Reserved blocks were also lowered to 1% via `tune2fs -m 1`,
  # which persists in the superblock — reclaims ~745 GiB from root's reserve.)
  fileSystems."/mnt/storage20tb" = {
    device = "/dev/disk/by-uuid/6d016e74-3cff-4f4d-8a8a-2769e7f35d76";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
      "noatime"
    ];
  };

  # 20TB USB archive disk (WD Elements, BOT-only bridge — no UAS available):
  # raise read-ahead from the 128 KB default to 2 MB for sequential throughput.
  # Re-applied on hotplug/USB reset because sysfs resets to default each time the
  # device re-enumerates (this bridge has been observed to reset). Keyed on the
  # drive serial so it can't match another disk if sdX letters shuffle.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ENV{ID_SERIAL_SHORT}=="21J3NTGF", ATTR{queue/read_ahead_kb}="2048"
  '';

  fileSystems."/export/storage20tb" = {
    device = "/mnt/storage20tb";
    options = [ "bind" ];
  };

  # Dropbox stores its sync folder at the default ~/Dropbox, which is a bind mount
  # onto the 20TB disk. Bind (not symlink) so the client sees a real ext4 dir and
  # doesn't refuse to run; nofail + requires-mounts-for so a missing USB disk
  # neither blocks boot nor starts the daemon against an empty home directory.
  fileSystems."/home/jamesbrink/Dropbox" = {
    device = "/mnt/storage20tb/Dropbox";
    options = [
      "bind"
      "nofail"
      "x-systemd.requires-mounts-for=/mnt/storage20tb"
    ];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export                 10.70.100.0/24(rw,fsid=0,no_subtree_check) 100.64.0.0/10(rw,fsid=0,no_subtree_check)
      /export/storage-fast    10.70.100.0/24(rw,nohide,insecure,no_subtree_check,crossmnt) 100.64.0.0/10(rw,nohide,insecure,no_subtree_check,crossmnt)
      /export/storage20tb     10.70.100.0/24(rw,nohide,insecure,no_subtree_check) 100.64.0.0/10(rw,nohide,insecure,no_subtree_check)
      /mnt/storage20tb/AI     10.70.100.0/24(rw,sync,insecure,no_subtree_check) 100.64.0.0/10(rw,sync,insecure,no_subtree_check)
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

  networking = {
    hostName = "hal9000";
    # Don't set a global domain to avoid search suffixes
    # domain = "home.urandom.io";
    useNetworkd = true;
    useDHCP = false;
    hostId = "e71a3d67";
    nftables = {
      enable = true;
    };
    search = [ ];

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
        5432 # PostgreSQL
        5900 # SPICE for VMs
        5901 # Additional SPICE ports
        5902
        5903
        5904
        7000 # AirPlay
        7001 # AirPlay
        7100 # AirPlay screen mirroring
        7865 # Fooocus web UI
        8188 # ComfyUI web UI
        8585 # Entropy (Tumblr likes archive)
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
        18789 # clawdbot
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
        18789 # clawdbot
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
            5432 # PostgreSQL
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

  # WiFi via iwd (radio link) + systemd-networkd (DHCP). Coexists with the br0
  # bridge stack; wired stays preferred. CLI: iwctl. GUI: iwgtk / iwgtk -i (tray).
  local.wifi.enable = true;

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
          # Removed "home.urandom.io" to prevent wildcard DNS conflicts with *.home.urandom.io
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

  # Standing Remote Control servers so the Claude app can start sessions here.
  # ~/Projects itself is not a trusted workspace yet; ~/Projects/jamesbrink is.
  services.claude-remote-control = {
    enable = true;
    servers.projects = {
      directory = "/home/jamesbrink/Projects/jamesbrink";
      name = "hal9000-projects";
      spawn = "same-dir";
      permissionMode = "acceptEdits";
    };
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

  # Orca runs as an on-demand child of the existing llama-swap endpoint.
  services.strata-orca = {
    enable = true;
    # Root is the Corsair MP600/ext4; storage-fast is the Crucial P3/ZFS.
    # Keep weights, native pack, tokenizer and MTP together on this SSD.
    # To relocate later: copy and verify the complete dataDir first, then
    # change this path and deploy. The module derives all runtime paths.
    # Old storage-fast weights were removed; historical reports remain there.
    dataDir = "/var/lib/strata-orca";
    # 64 GiB host: keep expert allocation bounded; require 36 GiB available.
    port = 18081;
    allowedDesktopComputeProcesses = [ "walker" ];
    maximumDesktopComputeMiB = 512;
    minimumFreeVRAMMiB = 20480;
    vramReserveMiB = 2048;
    memoryMode = "bounded-mmap";
    residentBudgetGiB = 24;
    residentHeadroomGiB = 8;
    # Total prompt + reasoning + answer capacity. Change this one setting to
    # switch windows: 32768 = 32K, 65536 = 64K. 128K needs a new hardware test.
    # 64K passed retrieval at 59469 input tokens; it trades GPU expert-cache
    # slots for context (7426 vs 7857 at 32K in the 7-worker screening run).
    # After activation, match OMP contextWindow to this value; keep its output
    # cap at 8192 and compact before the prompt consumes the remaining room.
    contextTokens = 65536;
    # Matched 2026-10-05 local trials; retain native PCIe bandwidth probing.
    prefillTokens = 2048;
    kvType = "fp16";
    specWindow = 4;
    mtpMaxT = 4;
    suffixDraft = 0;
    # The draft model keeps its own 32K window; this does not cap the target
    # at 32K. Keep it separate when changing contextTokens (64K was tested).
    mtpWindowTokens = 32768;
    poolWorkers = 23;
    poolAffinity = "all";
    pcieFraction = null;
  };

  # Exact recommended Q4_K_M, alongside IQ3_XXS. Shares contextTokens above.
  # Separate Strata pack/tokenizer; matching original MTP is shared read-only.
  # Its mmap weights remain on the root SSD; switching unloads the prior model.
  services.orca-q4.enable = true;

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    openFirewall = true;
    package = pkgs.ollamaPkgs.ollama-cuda;
    user = "ollama";
    group = "ollama";
    home = "/storage-fast/ollama";
    models = "/storage-fast/ollama/models";
    environmentVariables = {
      OLLAMA_ORIGINS = "*";
    };
  };

  # llama-swap: one OpenAI-compatible endpoint (:8080/v1) that starts the
  # llama-server for whichever model a request names and unloads it after
  # `ttl` idle seconds, so LLMs share the 4090 with ComfyUI/InvokeAI/mold.
  # Only one model is resident at a time (no groups); requesting another swaps.
  # Each model pins its own binary: Bonsai needs the PrismML fork
  # (overlays/llama-cpp-prism.nix) until its ternary kernels land upstream;
  # future stock-GGUF models can use pkgs.llama-cpp the same way.
  # GGUFs live on storage-fast/llm (recordsize=1M). `-lm none` (no mmap)
  # reads weights straight into VRAM instead of pinning a copy in ARC.
  #
  # Bonsai sizing, measured on the 4090 (2026-09-28, prism-87268f7):
  #   PTQ1_0 beats PQ2_0 on Ada: tg 98.5 vs 91.9 t/s, pp ~3500 t/s for both.
  #   q8_0 KV costs nothing vs f16 (80 t/s tg at 32K depth) and halves KV.
  #   8 slots on a unified KV pool: 98 t/s single stream, 330 t/s aggregate
  #   at 8 concurrent; every slot may use the full context.
  #   VRAM: 128K ctx = 13.0 GB, 256K ctx = 18.0 GB (f16 KV at 256K OOMs).
  #   Serving 256K only; deep agent contexts (30-78K each x8) drop decode to
  #   ~14 t/s per stream, and long prefills stall every stream while they run.
  # Bonsai MTP (2026-09-28): PQ2_0+MTP bundle with --spec-draft-n-max 1 vs
  # PTQ1_0 without speculation, 256K q8_0 KV, code/prose prompts:
  #   1 stream 112/102 vs 94/94 t/s; 4 concurrent 67/64 vs 38 t/s per stream
  #   (MTP sidesteps the slow batch 3-7 kernel path); 8 concurrent 354/324 vs
  #   277 t/s aggregate; at 60K depth x4 per-stream 15-18 vs 10-14 t/s.
  #   Draft acceptance 65-87%. n-max 2 was faster still (130 t/s single) but
  #   only fits at a 192K q8_0 pool, which overflowed at 4 x 60K contexts.
  #   q4_0 KV matched q8_0 speed (109/102 t/s single, 357/334 at 8).
  services.llama-swap = {
    enable = true;
    # Stable's v165 panicked under concurrent agent load ("sync: WaitGroup is
    # reused before previous Wait has returned" in Process.start, 2026-09-28);
    # upstream fixed several proxy.Process races/panics after it (#349, #363,
    # #378, #677). Same --listen/--config CLI.
    package = pkgs.unstablePkgs.llama-swap;
    port = 8080;
    openFirewall = true;
    settings = {
      healthCheckTimeout = 300;
      macros = {
        # -kvu: concurrent requests share one KV pool (slot count per model);
        # --cache-ram parks idle slots' prompt cache in host RAM when the pool
        # overflows (~38 KB/token at q8_0, 16 GB holds ~430K tokens).
        "prism-server" =
          "${lib.getExe' pkgs.llama-cpp-prism "llama-server"} --port \${PORT} --host 127.0.0.1 -ngl 99 -fa on --jinja -lm none -kvu --cache-ram 16384";
        "models" = "/storage-fast/llm/models";
      };
      # One entry per model and no aliases: two variants of one model made
      # llama-swap swap between them when clients mixed names, and each swap
      # drops every slot's prompt cache (agents then re-prefill 70K+ token
      # histories and decode fell to ~2 t/s, 2026-09-28).
      models."bonsai-2-27b" = {
        ttl = 1800;
        # llama-swap answers 429 past 10 in-flight requests by default; let
        # extra agent requests queue in llama-server instead.
        concurrencyLimit = 64;
        cmd = builtins.concatStringsSep " " [
          "\${prism-server}"
          # Official PQ2_0 + one community-trained MTP layer
          # (ProCreations/Ternary-Bonsai-2-27B-MTP; all 851 official tensors
          # verified byte-identical, only blk.64 added). Drafts are verified
          # by the main model, so output quality is unchanged.
          "-m \${models}/Ternary-Bonsai-2-27B-MTP/Ternary-Bonsai-2-27B-PQ2_0-MTP-Q8_0.gguf"
          "--spec-type draft-mtp --spec-draft-n-max 1"
          "--mmproj \${models}/Ternary-Bonsai-2-27B/Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf"
          # Qwen-VL grounding needs >=1024 image tokens (model KNOWN_ISSUES).
          "--image-min-tokens 1024"
          # The unified pool is shared by all 8 slots and requests fail with
          # "Context size has been exceeded" when agents' combined context
          # overflows it (70 failures at 256K on 2026-09-28). q4_0 KV fits a
          # 320K pool in 19.8 GB (2 GB headroom); 384K = 21.6 GB was too tight.
          "-c 327680 -ctk q4_0 -ctv q4_0 -np 8"
          # Reasoning counts against the output limit; small caps return
          # empty answers. Clients can still send max_tokens/reasoning_effort.
          "-n 32768"
          "--temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.05"
        ];
      };
      # Qwen3.8-27B does not fit beside Bonsai, so requesting it swaps Bonsai
      # out (and back on the next Bonsai request), dropping prompt caches both
      # ways. Short ttl hands the GPU back quickly. Measured on the 4090
      # (UD-Q4_K_M, q8_0 KV, prism-87268f7): 50 t/s single stream without
      # speculation; MTP draft (Q4_0, 3 tokens) gives 120-129 t/s on code and
      # 93 t/s on prose (acceptance ~80% / ~50%). The Q8_0 MTP draft and
      # DFlash OOM at 64K; DFlash matched MTP at 32K. 4 slots + vision, or
      # 128K ctx, do not fit: 64K x 2 slots + mmproj = 21.3 GB of ~21.9 free.
      models."qwen3.8-27b" = {
        ttl = 600;
        concurrencyLimit = 64;
        cmd = builtins.concatStringsSep " " [
          "\${prism-server}"
          "-m \${models}/Qwen3.8-27B/Qwen3.8-27B-UD-Q4_K_M.gguf"
          "--spec-type draft-mtp --spec-draft-n-max 3"
          "-md \${models}/Qwen3.8-27B/MTP/mtp-Qwen3.8-27B-Q4_0.gguf"
          "--mmproj \${models}/Qwen3.8-27B/mmproj-Qwen3.8-27B-Q8_0.gguf"
          "--image-min-tokens 1024"
          "-c 65536 -ctk q8_0 -ctv q8_0 -np 2"
          "-n 32768"
          "--temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0"
        ];
      };
    };
  };
  systemd.services.llama-swap = {
    after = [ "zfs-mount.service" ];
    serviceConfig = {
      # CUDA's driver maps W+X pages and reads /proc/driver/nvidia.
      MemoryDenyWriteExecute = lib.mkForce false;
      ProcSubset = lib.mkForce "all";
    };
  };

  # ComfyUI service (manual start: systemctl start comfyui)
  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    enableManager = true;
    port = 8188;
    listenAddress = "0.0.0.0";
    dataDir = "/home/jamesbrink/AI";
    user = "jamesbrink";
    group = "users";
    createUser = false;
    requiresMounts = [ "home-jamesbrink-AI.mount" ];
    extraArgs = [
      "--use-pytorch-cross-attention"
      "--cuda-malloc"
      "--lowvram"
    ];
  };

  # InvokeAI service (manual start: systemctl start invokeai)
  services.invokeai = {
    enable = true;
    dataDir = "/mnt/storage20tb/AI/InvokeAI";
    host = "0.0.0.0";
    port = 9090;
    openFirewall = true;
    user = "jamesbrink";
    group = "users";
    createUser = false;
    requiresMounts = [ "mnt-storage20tb.mount" ];
  };

  # Prevent GPU-hungry services from auto-starting — use systemctl start <service>
  systemd.services.comfyui.wantedBy = lib.mkForce [ ];
  systemd.services.invokeai.wantedBy = lib.mkForce [ ];

  # AI Toolkit training service
  services.ai-toolkit = {
    enable = true;
    dataDir = "/mnt/storage20tb/AI/ai-toolkit";
    host = "0.0.0.0";
    port = 8675;
    openFirewall = true;
    user = "jamesbrink";
    group = "users";
    createUser = false;
    requiresMounts = [ "mnt-storage20tb.mount" ];
    secrets = {
      claudeOauthTokenFile = config.age.secrets."claude-secondary".path;
      hfTokenFile = config.age.secrets."huggingface-token".path;
    };
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
      "mold-discord-token" = {
        file = "${secretsPath}/mold-discord-token.age";
        owner = "mold";
        group = "mold";
        mode = "0400";
      };
    };
  };

  virtualisation = {
    containers = {
      enable = true;
      # Runtime configuration using the correct NixOS structure
      containersConf.settings = {
        containers = {
          default_sysctls = [ ];
        };
      };
      # Specify crun as the OCI runtime
      ociSeccompBpfHook.enable = true;
    };
    podman = {
      enable = true;
      dockerCompat = false; # Disable docker compatibility to use real Docker
      defaultNetwork.settings.dns_enabled = true;
      extraPackages = with pkgs; [
        runc
        crun
        conmon
      ];
    };
    docker = {
      enable = true;
      # docker_28 is EOL/insecure as of Nov 2025 — track 29.x
      package = pkgs.docker_29;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      daemon.settings = {
        features = {
          buildkit = true;
        };
      };
      # NVIDIA GPU support is configured via hardware.nvidia-container-toolkit.enable = true
    };
    oci-containers = {
      containers = {
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
      # The module defaults to incus-lts, but 25.11's incus-lts is v6, which is
      # unsupported/insecure (CVE-2026-35527, -40195, -40197, -40251, -41647,
      # -41684, -41685, -40243, -41648). nixpkgs' own guidance is to move to the
      # `incus` package (v7) or NixOS 26.05. Also realigns the daemon with the
      # incus 7.x CLI already in systemPackages.
      package = pkgs.incus;
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
        # OVMF images are now available by default in 25.11
      };
      onBoot = "ignore";
      onShutdown = "shutdown";
      allowedBridges = [
        "virbr0"
        "br0"
      ];
    };
  };

  # Disabled - using Route53 for all home.urandom.io DNS
  services.internal-dns = {
    enable = false;
    domain = "home.urandom.io";
    primaryNameserver = "hal9000.home.urandom.io";
    adminEmail = "admin@home.urandom.io";
    listenAddresses = [
      "10.70.100.206"
      "127.0.0.1"
    ];
    allowedClients = [
      "10.42.0.0/15"
      "10.70.100.0/24"
      "127.0.0.1/32"
    ];
    records = [
      {
        name = "@";
        type = "A";
        value = "68.228.200.31";
      }
      {
        name = "hal9000";
        type = "A";
        value = "10.70.100.206";
      }
      {
        name = "alienware";
        type = "A";
        value = "10.70.100.205";
      }
      {
        name = "n100-01";
        type = "A";
        value = "10.70.100.201";
      }
      {
        name = "n100-02";
        type = "A";
        value = "10.70.100.202";
      }
      {
        name = "n100-03";
        type = "A";
        value = "10.70.100.203";
      }
      {
        name = "n100-04";
        type = "A";
        value = "10.70.100.204";
      }
      {
        name = "starlancer";
        type = "A";
        value = "192.168.0.97";
      }
      {
        name = "darkstarmk6mod1";
        type = "A";
        value = "192.168.0.151";
      }
      {
        name = "darkstar";
        type = "A";
        value = "100.127.113.116";
      }
      {
        name = "rancher";
        type = "A";
        value = "10.70.100.50";
      }
      {
        name = "k8s";
        type = "A";
        value = "10.70.100.50";
      }
      {
        name = "postgres";
        type = "CNAME";
        value = "k8s";
      }
      {
        name = "server02";
        type = "A";
        value = "10.70.100.192";
      }
      {
        name = "*.server02";
        type = "A";
        value = "10.70.100.192";
      }
    ];
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
    # Keep the driver initialised between CUDA clients so llama-swap/ollama
    # model loads skip GPU re-init after the last client exits.
    nvidiaPersistenced = true;
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
      # Disabled - conflicts with GNOME's gcr-ssh-agent in 25.11
      startAgent = false;
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
    # Mold CLI; the service module only wires the server binary
    inputs.mold.packages.x86_64-linux.mold
    # inputs.mold.packages.x86_64-linux.mold-desktop
    # unstablePkgs.exo
    audit
    bottles
    bridge-utils
    distrobox
    dropbox-cli # `dropbox` control CLI (status/puburl/exclude); daemon runs via systemd below
    websocketd
    dotnetPackages.Nuget
    exo
    mesa-demos
    incus
    nvidia-vaapi-driver
    nvtopPackages.nvidia
    OVMF
    pgweb
    podman
    podman-compose
    docker-compose
    crun
    runc
    samba4Full
    spice
    spice-gtk
    spice-protocol
    steam
    sunshine
    ollamaPkgs.ollama-cuda
    uxplay
    virt-viewer
    vulkan-tools
    winetricks
    wineWowPackages.waylandFull
    xorriso
    # GStreamer plugins for UxPlay
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
  ];

  system.stateVersion = "25.05";

  # Wait for br0 specifically to be routable (DHCP lease + default route).
  # --any let any link (e.g. enslaved enp6s0, link-local br0) satisfy
  # network-online.target before br0 had a default route, so k3s crashlooped
  # with "no default routes found" on every boot until its restart loop won.
  # Naming br0 also keeps a disconnected wlan0 from ever blocking boot.
  systemd.services.systemd-networkd-wait-online = {
    serviceConfig = {
      ExecStart = [
        ""
        "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --interface=br0:routable"
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
    fallbackDns = [ ];
    domains = [ ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "${config.age.secrets."hal9000-tailscale".path}";
  };

  # pgweb service configuration
  systemd.services.pgweb = {
    description = "pgweb PostgreSQL database browser";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PGHOST = "127.0.0.1";
      PGUSER = "postgres";
      PGDATABASE = "postgres";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.pgweb}/bin/pgweb --bind=0.0.0.0 --listen=8081 --host=127.0.0.1 --port=5432 --user=postgres --db=postgres --skip-open --sessions";
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

  # Enable TFTP server for N100 cluster netboot
  services.tftp-server = {
    enable = true;
    interface = "br0";
  };

  # Enable N100 netboot configuration file generation
  services.netbootConfigs = {
    enable = false; # temporarily disabled
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
  # Disabled by default (2026-08-28): flip to true and deploy to bring the
  # cluster (and the utensils/urandomio GitHub Actions runners) back up.
  services.k3s-cluster = {
    enable = false;
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
    nodeLabels = {
      "nvidia.com/gpu.present" = "true";
      "nvidia.com/gpu" = "true";
      "gpu-model" = "rtx4090";
      "node-role" = "master";
    };
    runnerTierLabel = "selfhost-l";
    certManager = {
      enable = true;
      email = "admin@home.urandom.io";
      # Switched to production after successful DNS01 validation on staging
      server = "https://acme-v02.api.letsencrypt.org/directory";
      issuerName = "letsencrypt-production";
      privateKeySecretName = "letsencrypt-production";
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
    dashboard = {
      enable = true;
      host = "traefik.home.urandom.io";
    };
    # No longer needed - Route53 handles all home.urandom.io DNS including ACME challenges
    coreDns.customServers = [ ];
  };

  # Zerobyte backup management service
  services.zerobyte = {
    enable = true;
    user = "root";
    group = "root";
    createUser = false;
    port = 4096;
    serverIp = "0.0.0.0";
    fuse.enable = true;
    protectHome = false;
    timezone = "America/Phoenix";
    resticHostname = "hal9000";
    extraReadWritePaths = [ "/mnt/storage20tb" ];
  };

  # Dropbox daemon for jamesbrink. Kept INSTALLED but NOT auto-started: the
  # account is over quota (lapsed billing) so the proprietary client can't get a
  # sync session, and the full library was rescued via rclone/Takeout instead.
  # `wantedBy = [ ]` means neither boot nor a deploy will launch it; the unit is
  # still defined, so `systemctl start dropbox` works if the account is ever paid
  # up and re-linked (`sudo -u jamesbrink HOME=/home/jamesbrink dropbox status`
  # prints the link URL). Its sync folder is ~/Dropbox, bind-mounted onto the
  # 20TB disk (see fileSystems above); RequiresMountsFor gates it on that disk.
  # The daemon (pkgs.dropbox) is referenced only by store path because it also
  # ships a /bin/dropbox that would collide with the dropbox-cli command.
  systemd.services.dropbox = {
    description = "Dropbox daemon (jamesbrink)";
    wantedBy = [ ]; # do not auto-start; manual `systemctl start dropbox` only
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.RequiresMountsFor = "/home/jamesbrink/Dropbox";
    environment.HOME = "/home/jamesbrink";
    serviceConfig = {
      Type = "simple";
      User = "jamesbrink";
      Group = "users";
      ExecStart = "${pkgs.dropbox}/bin/dropbox";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = "10s";
      Nice = 10;
    };
  };

  # Entropy — Tumblr likes archive (Flask gallery + gallery-dl downloader).
  # The code now comes from the flake (inputs.entropy, wired in flake.nix); only
  # mutable state lives on the storage-fast/entropy ZFS dataset: media, thumbs,
  # the state DB, logs, gallery-dl config and the OAuth/Shield credentials.
  #
  # user/group are the historical login account rather than the module's default
  # system user: the archive is owned jamesbrink:users, and naming an existing
  # account also makes the module skip user/group creation.
  #
  # No environmentFile — the Arachnid Shield credentials already live in
  # $ENTROPY_HOME/.env (mode 600), which arachnid.py reads directly. Ingest
  # screening is on by default and fails CRITICAL at startup if it cannot reach
  # Shield, rather than silently accepting unscreened media.
  services.entropy = {
    enable = true;
    user = "jamesbrink";
    group = "users";
    stateDir = "/storage-fast/entropy";
    openFirewall = true;
    backup = {
      enable = true;
      target = "/mnt/storage20tb/tumblr-likes";
    };
  };

  # stateDir is a ZFS dataset; the module only orders after network-online.
  # (ffmpeg, gallery-dl, sqlite, rsync are already in the package's wrapper PATH.)
  systemd.services.entropy.after = [ "zfs.target" ];

  # Mold AI image generation — home (db/cache/jobs) + output on the 20TB disk,
  # model weights on NVMe (see fileSystems."/storage-fast/mold")
  environment.variables.MOLD_HOME = "/mnt/storage20tb/AI/mold";
  environment.variables.MOLD_MODELS_DIR = "/storage-fast/mold/models";

  # Ensure ACLs on mold directories so files created by either the mold service
  # or jamesbrink (CLI) stay writable by both. g::rwx alone is not enough:
  # CLI-created files land as jamesbrink:users and mold is not in "users", so
  # named-user entries are required. The non-default pass repairs existing files.
  systemd.services.mold-acl = {
    description = "Set ACLs on mold directories";
    wantedBy = [ "multi-user.target" ];
    before = [ "mold.service" ];
    # No RemainAfterExit: the unit must return to inactive so the timer
    # below can re-trigger it (timers cannot start an already-active unit).
    serviceConfig.Type = "oneshot";
    script = ''
      for dir in /mnt/storage20tb/AI/mold /storage-fast/mold; do
        ${pkgs.acl}/bin/setfacl -R -d -m g::rwx,u:mold:rwx,u:jamesbrink:rwx "$dir"
        ${pkgs.acl}/bin/setfacl -R -m u:mold:rwX,u:jamesbrink:rwX "$dir"
      done

      # queue-media is the durable-admission "receipt authority" store and holds
      # master.key. mold refuses to enable canonical durable admission unless the
      # directory is owned by the service user with no group/other bits at all
      # (queue_media_store.rs: `metadata.permissions().mode() & 0o077 != 0`), so
      # the broad pass above disables the feature every time it runs. Re-tighten
      # it afterwards: strip the ACLs, then u=rwX,go= for 0700 dirs / 0600 files.
      for qm in /mnt/storage20tb/AI/mold/queue-media /storage-fast/mold/queue-media; do
        [ -d "$qm" ] || continue
        ${pkgs.acl}/bin/setfacl -R -b -k "$qm"
        chown -R mold:mold "$qm"
        find "$qm" -type d -exec chmod 0700 {} +
        find "$qm" -type f -exec chmod 0600 {} +
      done
    '';
  };

  # Re-run mold-acl periodically: dirs created by the CLI after boot (umask
  # 027 -> mode 0750) clamp the ACL mask to r-x, breaking mold writes until
  # the ACL pass repairs them (seen 2026-08-23 with a failed model pull).
  systemd.timers.mold-acl = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
  };

  # Allow mold server to access ~/AI bind mount for LoRAs and models
  systemd.services.mold.serviceConfig.ProtectHome = lib.mkForce false;
  systemd.services.mold.serviceConfig.ReadWritePaths = [
    "/mnt/storage20tb/AI"
    "/storage-fast/mold"
  ];
  # storage-fast/mold is mounted by zfs-mount.service (no fstab unit).
  systemd.services.mold.requires = [ "zfs-mount.service" ];
  systemd.services.mold.after = [ "zfs-mount.service" ];
  systemd.services.mold.unitConfig.AssertPathIsMountPoint = "/storage-fast/mold";
  # mold dies on SIGPIPE when a client connection drops mid-write (utensils/mold
  # upstream bug). systemd's default "clean exit" set includes SIGPIPE, so
  # Restart=on-failure treats it as success and never restarts. Force a restart
  # on SIGPIPE until the binary masks it. See upstream issue.
  systemd.services.mold.serviceConfig.RestartForceExitStatus = "SIGPIPE";

  # Binary cache for the mold flake
  nix.settings = {
    substituters = [ "https://mold.cachix.org" ];
    trusted-public-keys = [
      "mold.cachix.org-1:9HBc/bEXDdpbxMjOwpaIDpjZqBh9JYg0h5Fipm+D8m4="
    ];
  };

  services.mold = {
    enable = true;
    package = inputs.mold.packages.x86_64-linux.default;
    homeDir = "/mnt/storage20tb/AI/mold";
    modelsDir = "/storage-fast/mold/models";
    outputDir = "/mnt/storage20tb/AI/mold/output";
    hfTokenFile = config.age.secrets."huggingface-token".path;
    openFirewall = true;
    # Evict models parked in CPU RAM after 5 idle minutes (default 30).
    # The GPU-resident model is never evicted by this.
    environment.MOLD_CACHE_IDLE_TTL_SECS = "300";
    discord = {
      enable = true;
      tokenFile = config.age.secrets."mold-discord-token".path;
    };
  };

  # Plain PostgreSQL 17 for misc dev work, on the storage-fast/postgresql ZFS
  # dataset. Trust auth from localhost, the LAN and Tailscale only.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = true;
    authentication = lib.mkForce ''
      # TYPE  DATABASE  USER  ADDRESS         METHOD
      local   all       all                   trust
      host    all       all   127.0.0.1/32    trust
      host    all       all   ::1/128         trust
      host    all       all   10.70.100.0/24  trust
      host    all       all   100.64.0.0/10   trust
    '';
    ensureDatabases = [ "jamesbrink" ];
    ensureUsers = [
      {
        name = "jamesbrink";
        ensureDBOwnership = true;
        ensureClauses.superuser = true;
      }
    ];
  };

  # storage-fast/postgresql is mounted by zfs-mount.service (no fstab unit).
  # The assert keeps postgres from initdb-ing a fresh cluster on the root fs if
  # the dataset ever fails to mount.
  systemd.services.postgresql = {
    requires = [ "zfs-mount.service" ];
    after = [ "zfs-mount.service" ];
    unitConfig.AssertPathIsMountPoint = "/var/lib/postgresql";
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
