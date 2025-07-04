{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.netboot-server;

  # Netboot root directory on ZFS pool
  netbootRoot = "/export/storage-fast/netboot";

  # iPXE boot script generator
  makeBootScript =
    netbootRoot:
    pkgs.writeText "boot.ipxe" ''
      #!ipxe

      # Boot menu for N100 machines
      menu N100 Netboot Menu
      item --gap -- ------------------------- N100 Boot Options -------------------------
      item install    Install NixOS with ZFS (N100 Template)
      item rescue     NixOS Rescue Environment
      item local      Boot from local disk
      item --gap -- ------------------------- Advanced Options -------------------------
      item shell      iPXE Shell
      item reboot     Reboot
      choose --default local --timeout 10000 target && goto ''${target}

      :install
      echo Booting NixOS Installer with ZFS support...
      set base-url http://''${next-server}:${toString cfg.httpPort}
      kernel ''${base-url}/images/n100-installer/kernel initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0
      initrd ''${base-url}/images/n100-installer/initrd
      boot || goto failed

      :rescue
      echo Booting NixOS Rescue Environment...
      set base-url http://''${next-server}:${toString cfg.httpPort}
      kernel ''${base-url}/images/n100-rescue/kernel initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0
      initrd ''${base-url}/images/n100-rescue/initrd
      boot || goto failed

      :local
      echo Booting from local disk...
      exit

      :shell
      echo Entering iPXE shell...
      shell

      :reboot
      reboot

      :failed
      echo Boot failed, dropping to shell...
      shell
    '';
in
{
  options.services.netboot-server = {
    enable = mkEnableOption "NixOS netboot server for N100 cluster";

    interface = mkOption {
      type = types.str;
      default = "br0";
      description = "Network interface to serve PXE on";
    };

    httpPort = mkOption {
      type = types.port;
      default = 8079;
      description = "HTTP port for serving boot images";
    };
  };

  config = mkIf cfg.enable {
    # Create netboot directory structure
    systemd.tmpfiles.rules = [
      "d ${netbootRoot} 0755 root root -"
      "d ${netbootRoot}/images 0755 root root -"
      "d ${netbootRoot}/images/n100-installer 0755 root root -"
      "d ${netbootRoot}/images/n100-rescue 0755 root root -"
      "d ${netbootRoot}/scripts 0755 root root -"
      "d ${netbootRoot}/configs 0755 root root -"
      "d ${netbootRoot}/ipxe 0755 root root -"
    ];

    # Pixiecore PXE server
    services.pixiecore = {
      enable = true;
      openFirewall = true;
      dhcpNoBind = true; # Work alongside existing DHCP
      port = cfg.httpPort;
      mode = "boot";
      kernel = "http://boot.netboot.xyz"; # Will be replaced with custom iPXE
      cmdLine = "";
    };

    # Override pixiecore to use our custom iPXE script
    systemd.services.pixiecore = {
      serviceConfig = {
        ExecStart = mkForce "${pkgs.pixiecore}/bin/pixiecore \
          boot \
          --port ${toString cfg.httpPort} \
          --status-port ${toString (cfg.httpPort + 1)} \
          --dhcp-no-bind \
          --ipxe-script-url http://\${next-server}:${toString cfg.httpPort}/ipxe/boot.ipxe \
          ${pkgs.ipxe}/ipxe.pxe";
      };
    };

    # Nginx for serving netboot files
    services.nginx.virtualHosts."netboot.${config.networking.domain}" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = cfg.httpPort;
        }
      ];
      root = netbootRoot;
      extraConfig = ''
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
      '';
      locations = {
        "/" = {
          extraConfig = ''
            allow 10.70.100.0/24;
            allow 100.64.0.0/10;
            deny all;
          '';
        };
      };
    };

    # Copy iPXE boot script
    system.activationScripts.netboot-ipxe = ''
      mkdir -p ${netbootRoot}/ipxe
      cp ${makeBootScript netbootRoot} ${netbootRoot}/ipxe/boot.ipxe
      chmod 644 ${netbootRoot}/ipxe/boot.ipxe
    '';

    # NFS exports for netboot (if needed for diskless boot)
    services.nfs.server.exports = ''
      ${netbootRoot}/images *(ro,no_subtree_check,no_root_squash)
    '';
  };
}
