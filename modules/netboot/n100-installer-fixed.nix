{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    # Base netboot installer
    (modulesPath + "/installer/netboot/netboot-minimal.nix")
    # Static SSH host keys for consistent fingerprint
    ./installer-ssh-keys.nix
  ];

  # System configuration for the installer
  networking.hostName = "nixos-installer";

  # Enable console access and auto-login for debugging
  services.getty.autologinUser = lib.mkForce "root";

  # Enable getty on VGA console only
  systemd.services."getty@tty1".enable = true;
  systemd.services."getty@tty1".wantedBy = [ "multi-user.target" ];

  # Disable serial getty to prevent shutdown hang
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."getty@ttyS0".enable = false;

  # Create marker file to identify this as the installer
  system.activationScripts.installerMarker = ''
    touch /etc/is-installer
  '';

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  # Add SSH keys for root access during installation
  users.users.root.openssh.authorizedKeys.keys = [
    # SSH public keys for user jamesbrink
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
    # System keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARkb1kXdTi41j9j9JLPtY1+HxskjrSCkqyB5Dx0vcqj root@Alienware15R4"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkFHSY+3XcW54uu4POE743wYdh4+eGIR68O8121X29m root@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRNDnoVLI8Zy9YjOkHQuX6m9f9EzW8W2lYxnoGDjXtM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSf4Qft9nUD2gRDeJVkogYKY7PQvhlnD+kjFKgro3r"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKlaSFMo6Wcm5oZu3ABjPY4Q+INQBlVwxVktjfz66oI root@n100-04"
  ];

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Essential packages for installation
  environment.systemPackages = with pkgs; [
    # Disk management
    parted
    gptfdisk
    cryptsetup
    disko

    # ZFS tools
    zfs

    # Network tools
    iproute2
    ethtool
    tcpdump
    nmap

    # System tools
    vim
    tmux
    htop
    iotop
    ncdu
    tree

    # Installation helpers
    git
    curl
    wget
    rsync

    # Hardware info
    pciutils
    usbutils
    dmidecode
    lshw
  ];

  # Kernel modules for N100 hardware
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];

  # Network configuration - use DHCP for all interfaces
  networking.useDHCP = true;
  networking.networkmanager.enable = false; # Use systemd-networkd in installer

  # Don't wait for specific interfaces that might not exist
  systemd.network.wait-online.anyInterface = true;
  systemd.network.wait-online.timeout = 30; # Reduce timeout from default 120s

  # Enable predictable network interface names
  networking.usePredictableInterfaceNames = false;

  # Auto-installer script location
  environment.etc."n100-auto-install.sh" = {
    source = ./auto-install.sh;
    mode = "0755";
  };

  # Message of the day
  environment.etc."motd".text = ''

    ╔═══════════════════════════════════════════════════════════════╗
    ║                 NixOS N100 Cluster Installer                  ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║                                                               ║
    ║  This is a specialized installer for N100 cluster nodes.      ║
    ║                                                               ║
    ║  Available commands:                                          ║
    ║    - n100-install     : Run automated installation            ║
    ║    - n100-install-manual : Run manual installation            ║
    ║    - lsblk           : List block devices                     ║
    ║    - ip addr         : Show network configuration             ║
    ║    - zpool status    : Check ZFS pools                        ║
    ║                                                               ║
    ║  SSH is enabled. Connect as root to install remotely.         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

  '';

  # Create installer command aliases
  environment.shellAliases = {
    n100-install = "/etc/n100-auto-install.sh";
    n100-install-manual = "echo 'Starting manual installation...' && sleep 2";
  };

  # Ensure installer starts with a shell
  services.getty.helpLine = ''

    <<< NixOS N100 Installer - Run 'n100-install' to begin >>>
  '';

  # Add a custom issue file for login prompt
  environment.etc."issue".text = ''

    ╔═══════════════════════════════════════════════════════════════╗
    ║                 NixOS N100 Cluster Installer                  ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Auto-login enabled as root - no password required            ║
    ╚═══════════════════════════════════════════════════════════════╝

  '';

  # Ensure network comes up before SSH
  systemd.services.sshd = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # Enable more verbose boot messages - but only on VGA console
  boot.consoleLogLevel = 7;
  boot.kernelParams = lib.mkForce [
    "console=tty0"
    "loglevel=7"
    "systemd.log_level=debug"
  ];

  # Disable systemd's default behavior of stopping getty on shutdown
  systemd.services."getty@".serviceConfig.IgnoreOnIsolate = true;

  # Ensure clean shutdown
  systemd.shutdownRamfs.enable = true;
}
