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

      # ${hostname} boot script (hostname-based detection)
      # Expected MAC: ${mac}
      # Expected IP: ${ip}
      echo Detected hostname: ${hostname}
      echo
      echo ========================================
      echo Default: Boot from local disk
      echo Fallback: Network installer if disk fails
      echo Timeout: 20 seconds
      echo ========================================
      echo

      # Set variables
      set base-url http://''${next-server}:8079
      set hostname ${hostname}

      # Verify MAC address matches expected
      iseq ''${mac} ${mac} && goto verified ||
      echo WARNING: MAC address mismatch!
      echo Expected: ${mac}
      echo Actual: ''${mac}
      prompt Press any key to continue anyway...

      :verified
      # Set menu timeout to 20 seconds
      set menu-timeout 20000
      set menu-default local_disk

      # Display countdown menu
      menu ${hostname} Boot Menu
      item --default local_disk --key l local_disk    Boot from local disk
      item --key n netboot                             Network installer
      item --key r rescue                              Network rescue mode
      item --key s shell                               iPXE shell
      choose --timeout ''${menu-timeout} --default ''${menu-default} selected || goto local_disk

      # Jump to selected option
      goto ''${selected}

      :local_disk
      echo Attempting to boot from local disk...
      # Try to exit iPXE and continue normal boot sequence
      exit 0 || goto try_sanboot

      :try_sanboot
      # If exit doesn't work, try sanboot (boot from local disk)
      echo Trying sanboot for local disk...
      sanboot --no-describe --drive 0x80 || goto netboot

      :netboot
      echo
      echo Local disk boot failed or was interrupted
      echo Starting network installer for ${hostname}...
      echo

      # Chain to NixOS installer
      # Load kernel command line from server (contains the dynamic init path)
      chain ''${base-url}/images/n100-installer/cmdline.ipxe || goto failed

      :rescue
      echo Starting network rescue mode for ${hostname}...
      # Load kernel command line from server (contains the dynamic init path)
      chain ''${base-url}/images/n100-rescue/cmdline.ipxe || goto failed

      :shell
      echo Entering iPXE shell...
      echo Type 'exit' to return to menu
      shell
      goto verified

      :failed
      echo Boot failed!
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
      echo Detected MAC ${mac} - System: ${hostname}
      echo
      echo ========================================
      echo Default: Boot from local disk
      echo Fallback: Network installer if disk fails
      echo Timeout: 20 seconds
      echo ========================================
      echo

      # Set menu timeout to 20 seconds
      set menu-timeout 20000
      set menu-default local_disk

      # Display countdown menu
      menu ${hostname} Boot Menu
      item --default local_disk --key l local_disk    Boot from local disk
      item --key n netboot                             Network installer
      item --key r rescue                              Network rescue mode
      item --key s shell                               iPXE shell
      choose --timeout ''${menu-timeout} --default ''${menu-default} selected || goto local_disk

      # Jump to selected option
      goto ''${selected}

      :local_disk
      echo Attempting to boot from local disk...
      # Try to exit iPXE and continue normal boot sequence
      # This will cause the BIOS/UEFI to try the next boot device (usually the local disk)
      exit 0 || goto try_sanboot

      :try_sanboot
      # If exit doesn't work, try sanboot (boot from local disk)
      echo Trying sanboot for local disk...
      sanboot --no-describe --drive 0x80 || goto netboot

      :netboot
      echo
      echo Local disk boot failed or was interrupted
      echo Starting network installer for ${hostname}...
      echo

      # Set variables
      set base-url http://''${next-server}:8079
      set hostname ${hostname}
      set expected-mac ${mac}

      # Chain to NixOS installer
      # Load kernel command line from server (contains the dynamic init path)
      chain ''${base-url}/images/n100-installer/cmdline.ipxe || goto failed

      :rescue
      echo Starting network rescue mode for ${hostname}...
      set base-url http://''${next-server}:8079
      # Load kernel command line from server (contains the dynamic init path)
      chain ''${base-url}/images/n100-rescue/cmdline.ipxe || goto failed

      :shell
      echo Entering iPXE shell...
      echo Type 'exit' to return to menu
      shell
      goto menu

      :failed
      echo Boot failed!
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
