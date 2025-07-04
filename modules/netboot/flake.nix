{
  description = "NixOS netboot images for N100 cluster";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Build the installer system
      installerSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./n100-installer.nix
          disko.nixosModules.disko
          (
            { config, pkgs, ... }:
            {
              # Override the auto-install script path
              environment.etc."n100-auto-install.sh" = {
                source = ./auto-install.sh;
                mode = "0755";
              };
              # Ensure disko is available
              environment.systemPackages = [ disko.packages.${system}.default ];
            }
          )
        ];
      };

      # Build the rescue system
      rescueSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          (nixpkgs + "/nixos/modules/installer/netboot/netboot-minimal.nix")
          (
            { config, pkgs, ... }:
            {
              networking.hostName = "nixos-rescue";

              # Enable SSH
              services.openssh = {
                enable = true;
                settings = {
                  PermitRootLogin = "yes";
                  PasswordAuthentication = false;
                };
              };

              # Add SSH keys
              users.users.root.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
              ];

              # ZFS support
              boot.supportedFilesystems = [ "zfs" ];

              # Rescue tools
              environment.systemPackages = with pkgs; [
                # Disk tools
                parted
                gptfdisk
                ddrescue
                testdisk

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

              # MOTD for rescue mode
              environment.etc."motd".text = ''

                ╔═══════════════════════════════════════════════════════════════╗
                ║                   NixOS Rescue Environment                    ║
                ╠═══════════════════════════════════════════════════════════════╣
                ║                                                               ║
                ║  This is a rescue environment for N100 cluster nodes.         ║
                ║                                                               ║
                ║  Available tools:                                             ║
                ║    - ZFS utilities (zpool, zfs)                               ║
                ║    - Disk utilities (parted, gptfdisk, ddrescue)             ║
                ║    - Network tools (ip, ethtool, tcpdump)                    ║
                ║    - System utilities (vim, tmux, htop)                       ║
                ║                                                               ║
                ║  SSH is enabled. Connect as root for remote recovery.         ║
                ║                                                               ║
                ╚═══════════════════════════════════════════════════════════════╝

              '';
            }
          )
        ];
      };
    in
    {
      # Build netboot images
      packages.${system} = {
        # N100 installer netboot files
        n100-installer = pkgs.stdenv.mkDerivation {
          name = "n100-installer-netboot";
          buildInputs = [
            installerSystem.config.system.build.kernel
            installerSystem.config.system.build.netbootRamdisk
          ];
          buildCommand = ''
            mkdir -p $out
            cp ${installerSystem.config.system.build.kernel}/bzImage $out/kernel
            cp ${installerSystem.config.system.build.netbootRamdisk}/initrd $out/initrd
            echo "${installerSystem.config.system.build.toplevel}" > $out/system-path
          '';
        };

        # Rescue netboot files
        n100-rescue = pkgs.stdenv.mkDerivation {
          name = "n100-rescue-netboot";
          buildInputs = [
            rescueSystem.config.system.build.kernel
            rescueSystem.config.system.build.netbootRamdisk
          ];
          buildCommand = ''
            mkdir -p $out
            cp ${rescueSystem.config.system.build.kernel}/bzImage $out/kernel
            cp ${rescueSystem.config.system.build.netbootRamdisk}/initrd $out/initrd
            echo "${rescueSystem.config.system.build.toplevel}" > $out/system-path
          '';
        };

        # Build script for copying images to HAL9000
        deploy-images = pkgs.writeScriptBin "deploy-netboot-images" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          echo "Building netboot images..."
          nix build .#n100-installer --impure
          nix build .#n100-rescue --impure

          echo "Deploying to HAL9000..."
          NETBOOT_ROOT="/export/storage-fast/netboot"

          # Deploy installer
          ssh hal9000 "mkdir -p $NETBOOT_ROOT/images/n100-installer"
          scp result/kernel hal9000:$NETBOOT_ROOT/images/n100-installer/
          scp result/initrd hal9000:$NETBOOT_ROOT/images/n100-installer/
          SYSTEM_PATH=$(cat result/system-path)
          ssh hal9000 "echo 'init=$SYSTEM_PATH/init' > $NETBOOT_ROOT/images/n100-installer/cmdline"

          # Deploy rescue
          nix build .#n100-rescue --impure
          ssh hal9000 "mkdir -p $NETBOOT_ROOT/images/n100-rescue"
          scp result/kernel hal9000:$NETBOOT_ROOT/images/n100-rescue/
          scp result/initrd hal9000:$NETBOOT_ROOT/images/n100-rescue/
          SYSTEM_PATH=$(cat result/system-path)
          ssh hal9000 "echo 'init=$SYSTEM_PATH/init' > $NETBOOT_ROOT/images/n100-rescue/cmdline"

          echo "Netboot images deployed successfully!"
        '';
      };

      # Default package
      defaultPackage.${system} = self.packages.${system}.deploy-images;
    };
}
