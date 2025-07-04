{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.tftp-server;

  # TFTP root directory on ZFS pool
  tftpRoot = "/export/storage-fast/netboot/tftp";

  # Import N100 network configuration
  n100Config = import ../n100-network.nix;

  # Import netboot.xyz package
  netbootXyz = pkgs.callPackage ../../pkgs/netboot-xyz { };

  # Hostname-based iPXE scripts for N100 machines
  makeHostnameIpxe =
    hostname: hostNum:
    let
      nodeInfo = n100Config.n100-network.nodes.${hostname};
      mac = nodeInfo.mac;
      ip = nodeInfo.ip;
    in
    pkgs.writeText "HOSTNAME-${hostname}.ipxe" ''
      #!ipxe

      # ${hostname} boot script
      # Expected MAC: ${mac}
      # Expected IP: ${ip}
      echo Booting ${hostname} from netboot server...

      # Set variables
      set base-url http://''${next-server}:8079
      set hostname ${hostname}

      # Show what we're doing
      echo Hostname: ''${hostname}
      echo MAC: ''${mac}
      echo IP: ''${ip}
      echo Next-server: ''${next-server}

      # Verify MAC address matches expected
      iseq ''${mac} ${mac} && goto mac_ok ||
      echo WARNING: MAC address mismatch!
      echo Expected: ${mac}
      echo Actual: ''${mac}
      prompt Press any key to continue anyway...

      :mac_ok
      # Chain to NixOS installer
      echo Loading NixOS installer for ${hostname}...
      kernel ''${base-url}/images/n100-installer/kernel init=/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-nixos-system-installer/init initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=${hostname}
      initrd ''${base-url}/images/n100-installer/initrd
      boot || goto failed

      :failed
      echo Boot failed for ${hostname}
      prompt Press any key to reboot
      reboot
    '';

  # MAC address-based iPXE scripts (auto-boot without hostname detection)
  makeMacIpxe =
    hostname: hostNum:
    let
      nodeInfo = n100Config.n100-network.nodes.${hostname};
      mac = nodeInfo.mac;
      ip = nodeInfo.ip;
      # Convert MAC to filename format (replace : with -)
      macFilename = builtins.replaceStrings [ ":" ] [ "-" ] mac;
    in
    pkgs.writeText "01-${macFilename}.ipxe" ''
      #!ipxe

      # Auto-boot script for ${hostname} (MAC: ${mac})
      echo Detected MAC ${mac} - Auto-booting ${hostname}...

      # Set variables
      set base-url http://''${next-server}:8079
      set hostname ${hostname}
      set expected-mac ${mac}

      # Chain to NixOS installer with automatic installation
      echo Loading NixOS installer for ${hostname} (automatic installation)...
      kernel ''${base-url}/images/n100-installer/kernel init=/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-nixos-system-installer/init initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=${hostname} autoinstall=true
      initrd ''${base-url}/images/n100-installer/initrd
      boot || goto failed

      :failed
      echo Boot failed for ${hostname}
      prompt Press any key to reboot
      reboot
    '';
in
{
  options.services.tftp-server = {
    enable = mkEnableOption "TFTP server for netboot";

    interface = mkOption {
      type = types.str;
      default = "br0";
      description = "Network interface to bind to";
    };

    extraFiles = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Extra files to serve via TFTP";
    };
  };

  config = mkIf cfg.enable {
    # Create TFTP directory structure
    systemd.tmpfiles.rules = [
      "d ${tftpRoot} 0755 nobody nogroup -"
    ];

    # TFTP server using tftp-hpa
    services.atftpd = {
      enable = true;
      root = tftpRoot;
      extraOptions = [
        "--verbose=7"
        "--trace"
      ];
    };

    # Open firewall for TFTP (UDP port 69)
    networking.firewall = {
      allowedUDPPorts = [ 69 ];
      # TFTP uses random high ports for data transfer
      allowedUDPPortRanges = [
        {
          from = 32768;
          to = 65535;
        }
      ];
    };

    # Install hostname-based iPXE scripts
    system.activationScripts.tftp-files = ''
      echo "Setting up TFTP netboot files..."

      # Create directory if it doesn't exist
      mkdir -p ${tftpRoot}

      # Copy hostname-based iPXE scripts
      cp ${makeHostnameIpxe "n100-01" "01"} ${tftpRoot}/HOSTNAME-n100-01.ipxe
      cp ${makeHostnameIpxe "n100-02" "02"} ${tftpRoot}/HOSTNAME-n100-02.ipxe
      cp ${makeHostnameIpxe "n100-03" "03"} ${tftpRoot}/HOSTNAME-n100-03.ipxe
      cp ${makeHostnameIpxe "n100-04" "04"} ${tftpRoot}/HOSTNAME-n100-04.ipxe

      # Copy MAC address-based iPXE scripts for automatic boot
      cp ${makeMacIpxe "n100-01" "01"} ${tftpRoot}/01-e0-51-d8-12-ba-97.ipxe
      cp ${makeMacIpxe "n100-02" "02"} ${tftpRoot}/01-e0-51-d8-13-04-50.ipxe
      cp ${makeMacIpxe "n100-03" "03"} ${tftpRoot}/01-e0-51-d8-13-4e-91.ipxe
      cp ${makeMacIpxe "n100-04" "04"} ${tftpRoot}/01-e0-51-d8-15-46-4e.ipxe

      # Copy latest netboot.xyz bootloaders
      cp ${netbootXyz}/netboot.xyz.kpxe ${tftpRoot}/netboot.xyz.kpxe
      echo "Installed netboot.xyz.kpxe version 2.0.87"

      cp ${netbootXyz}/netboot.xyz.efi ${tftpRoot}/netboot.xyz.efi
      echo "Installed netboot.xyz.efi version 2.0.87"

      # Copy any extra files
      ${concatStringsSep "\n" (
        mapAttrsToList (name: path: ''
          cp ${path} ${tftpRoot}/${name}
        '') cfg.extraFiles
      )}

      # Set proper permissions
      chown -R nobody:nogroup ${tftpRoot}
      chmod -R 755 ${tftpRoot}

      echo "TFTP setup complete. Files in ${tftpRoot}:"
      ls -la ${tftpRoot}/
    '';

    # Add helpful commands to check TFTP status
    environment.systemPackages = with pkgs; [
      tftp-hpa # TFTP client for testing
      atftp # Alternative TFTP client
    ];
  };
}
