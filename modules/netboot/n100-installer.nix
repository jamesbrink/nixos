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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
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

  # Enable DHCP on common interface names
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;

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
}
