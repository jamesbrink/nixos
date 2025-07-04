{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.netboot-autochain;

  # Auto-chain script that netboot.xyz will load
  # This needs to be served at a predictable URL
  # Note: The init path will be updated by the build script
  autoChainScript = pkgs.writeText "autochain.ipxe" ''
    #!ipxe

    # N100 MAC Address Auto-detection and Boot
    # This script is automatically loaded by netboot.xyz custom URL feature

    echo N100 Auto-boot Detection Script
    echo Checking MAC address: ''${mac}

    # N100-01
    iseq ''${mac} e0:51:d8:12:ba:97 && goto boot_n100_01 ||

    # N100-02
    iseq ''${mac} e0:51:d8:13:04:50 && goto boot_n100_02 ||

    # N100-03
    iseq ''${mac} e0:51:d8:13:4e:91 && goto boot_n100_03 ||

    # N100-04
    iseq ''${mac} e0:51:d8:15:46:4e && goto boot_n100_04 ||

    # Not an N100 node - exit back to netboot.xyz menu
    echo Not an N100 node - returning to menu
    exit 0

    :boot_n100_01
    echo Detected N100-01 - Loading NixOS installer...
    set hostname n100-01
    goto boot_nixos

    :boot_n100_02
    echo Detected N100-02 - Loading NixOS installer...
    set hostname n100-02
    goto boot_nixos

    :boot_n100_03
    echo Detected N100-03 - Loading NixOS installer...
    set hostname n100-03
    goto boot_nixos

    :boot_n100_04
    echo Detected N100-04 - Loading NixOS installer...
    set hostname n100-04
    goto boot_nixos

    :boot_nixos
    set base-url http://''${next-server}:8079
    echo Loading NixOS installer for ''${hostname} (automatic installation)...
    kernel ''${base-url}/images/n100-installer/kernel init=/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-nixos-system-installer/init initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=''${hostname} autoinstall=true
    initrd ''${base-url}/images/n100-installer/initrd
    boot || goto failed

    :failed
    echo Boot failed for ''${hostname}
    prompt Press any key to return to menu...
    exit 1
  '';
in
{
  options.services.netboot-autochain = {
    enable = mkEnableOption "Netboot.xyz auto-chain for N100 nodes";
  };

  config = mkIf cfg.enable {
    # Add the autochain script to nginx
    services.nginx.virtualHosts."netboot.home.urandom.io" = {
      locations."= /autochain.ipxe" = {
        extraConfig = ''
          # Serve the auto-chain script (exact match to avoid path traversal)
          alias ${autoChainScript};
          add_header Content-Type "text/plain";

          # Allow access from N100 network and Tailscale
          allow 10.70.100.0/24;
          allow 100.64.0.0/10;
          deny all;
        '';
      };
    };
  };
}
