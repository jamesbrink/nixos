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
  imports = [
    ./hardware-configuration.nix
    ../../modules/shared-packages/default.nix
    ../../modules/shared-packages/devops.nix
    ../../users/regular/jamesbrink.nix
    ../../profiles/desktop/default-stable.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Swap file configuration
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024; # 32GB
    }
  ];

  # Prevent sleep/hibernation (useful for iMac)
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Networking
  networking.hostName = "sevastopol";
  networking.networkmanager.enable = true;

  # Timezone and locale
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

  # Enable automatic login for the user
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "jamesbrink";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # SSH configuration - temporary password auth until keys are set up
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  # Enable zsh (required for user shell)
  programs.zsh.enable = true;

  # Enable RPC bind service (required for NFS)
  services.rpcbind.enable = true;

  # NFS mounts
  systemd.mounts = [
    {
      type = "nfs";
      mountConfig.Options = "noatime";
      what = "alienware.home.urandom.io:/storage";
      where = "/mnt/storage";
    }
    {
      type = "nfs";
      mountConfig.Options = "noatime";
      what = "hal9000.home.urandom.io:/storage-fast";
      where = "/mnt/storage-fast";
    }
  ];

  systemd.automounts = [
    {
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "600";
      where = "/mnt/storage";
    }
    {
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "600";
      where = "/mnt/storage-fast";
    }
  ];

  # Create mount points
  systemd.tmpfiles.rules = [
    "d /mnt 0775 root users"
    "d /mnt/storage 0775 root users"
    "d /mnt/storage-fast 0775 root users"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
