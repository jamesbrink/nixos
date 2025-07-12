{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.windows11-vm;
  # Windows 11 VM configuration
  vmName = "win11-dev";
in
{
  options.services.windows11-vm = {
    enable = mkEnableOption "Windows 11 development VM";

    memory = mkOption {
      type = types.int;
      default = 16;
      description = "Memory allocation in GiB";
    };

    vcpus = mkOption {
      type = types.int;
      default = 8;
      description = "Number of virtual CPUs";
    };

    diskSize = mkOption {
      type = types.str;
      default = "100G";
      description = "Disk size for the VM";
    };

    diskPath = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/images/${vmName}.qcow2";
      description = "Path to the VM disk image";
    };

    autostart = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to autostart the VM";
    };

    owner = mkOption {
      type = types.str;
      default = "jamesbrink";
      description = "User who owns and can manage the VM";
    };

    windowsISO = mkOption {
      type = types.str;
      default = "/var/lib/libvirt/images/Win11_24H2_English_x64.iso";
      description = "Path to Windows 11 installation ISO";
    };
  };

  config = mkIf cfg.enable {
    # Ensure swtpm is enabled for TPM 2.0
    virtualisation.libvirtd.qemu.swtpm.enable = true;

    # Ensure user is in libvirtd group
    users.users.${cfg.owner}.extraGroups = [ "libvirtd" ];

    # Create storage directory
    systemd.tmpfiles.rules = [
      "d /var/lib/libvirt/images 0775 root libvirtd"
    ];

    # Create and manage the VM
    systemd.services.windows11-vm-setup = {
      description = "Setup Windows 11 VM";
      after = [
        "libvirtd.service"
        "libvirtd-network-bridge.service"
      ];
      requires = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Download VirtIO drivers if not present
        if [ ! -f /var/lib/libvirt/images/virtio-win.iso ]; then
          echo "Downloading VirtIO drivers..."
          ${pkgs.wget}/bin/wget -q -O /var/lib/libvirt/images/virtio-win.iso \
            https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
        fi

        # Check if VM already exists
        if ! ${pkgs.libvirt}/bin/virsh list --all | grep -q " ${vmName} "; then
          echo "Creating VM with virt-install..."
          
          # Parse disk size (remove G suffix if present)
          diskSizeNum=$(echo "${cfg.diskSize}" | sed 's/[^0-9]//g')
          
          ${pkgs.virt-manager}/bin/virt-install \
            --name ${vmName} \
            --memory ${toString (cfg.memory * 1024)} \
            --vcpus ${toString cfg.vcpus} \
            --cpu host-passthrough,+vmx \
            --disk path=${cfg.diskPath},format=qcow2,bus=sata,size=$diskSizeNum \
            --cdrom ${cfg.windowsISO} \
            --disk /var/lib/libvirt/images/virtio-win.iso,device=cdrom,bus=sata \
            --network bridge=br0,model=virtio \
            --graphics spice,listen=localhost \
            --video qxl \
            --sound ich9 \
            --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 \
            --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
            --boot uefi \
            --features smm=on \
            --osinfo win11 \
            --noautoconsole \
            --noreboot \
            --import
            
          # Set ownership on the disk
          chown ${cfg.owner}:libvirtd "${cfg.diskPath}"
          chmod 660 "${cfg.diskPath}"
        fi

        # Set autostart if configured
        if [ "${toString cfg.autostart}" = "1" ]; then
          ${pkgs.libvirt}/bin/virsh autostart ${vmName}
        else
          ${pkgs.libvirt}/bin/virsh autostart --disable ${vmName}
        fi
      '';
    };

    # Helper script for the user
    environment.systemPackages = [
      (pkgs.writeScriptBin "win11-vm" ''
        #!${pkgs.bash}/bin/bash

        case "$1" in
          start)
            virsh start ${vmName}
            echo "Windows 11 VM started. Connect with: virt-viewer ${vmName}"
            ;;
          stop)
            virsh shutdown ${vmName}
            ;;
          force-stop)
            virsh destroy ${vmName}
            ;;
          status)
            virsh dominfo ${vmName}
            ;;
          console)
            virt-viewer ${vmName}
            ;;
          *)
            echo "Usage: $0 {start|stop|force-stop|status|console}"
            echo ""
            echo "VM is configured with:"
            echo "- Windows 11 ISO at: ${cfg.windowsISO}"
            echo "- VirtIO drivers at: /var/lib/libvirt/images/virtio-win.iso"
            echo "- Main disk using SATA interface (no drivers needed for installation)"
            echo ""
            echo "During installation:"
            echo "1. win11-vm start"
            echo "2. win11-vm console"
            echo "3. Install normally - disk should be visible"
            echo "4. For network/graphics drivers, use D: drive (VirtIO ISO)"
            exit 1
            ;;
        esac
      '')
    ];
  };
}

