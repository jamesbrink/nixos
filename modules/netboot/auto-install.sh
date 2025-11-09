#!/usr/bin/env bash
set -euo pipefail

# N100 Automated NixOS Installation Script with ZFS
# Based on N100-04 configuration template

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
POOL_NAME="zpool"
MOUNT_POINT="/mnt"

# Check for kernel parameters
check_kernel_params() {
    # Check for autoinstall=true in kernel parameters
    if grep -q "autoinstall=true" /proc/cmdline; then
        AUTO_INSTALL=true
        log_info "Auto-install mode enabled"
    else
        AUTO_INSTALL=false
    fi
    
    # Check for hostname in kernel parameters
    if grep -oE 'hostname=n100-0[1-4]' /proc/cmdline > /dev/null; then
        HOSTNAME=$(grep -oE 'hostname=n100-0[1-4]' /proc/cmdline | cut -d= -f2)
        log_info "Hostname from kernel parameter: $HOSTNAME"
        HOSTNAME_FROM_KERNEL=true
    else
        HOSTNAME_FROM_KERNEL=false
    fi
}

# Detect hostname from DHCP or prompt
detect_hostname() {
    # First check if we already have hostname from kernel parameter
    if [ "$HOSTNAME_FROM_KERNEL" = true ]; then
        log_info "Using hostname from kernel parameter: $HOSTNAME"
        return
    fi
    
    local dhcp_hostname
    dhcp_hostname=$(hostname)
    if [[ "$dhcp_hostname" =~ ^n100-0[1-4]$ ]]; then
        HOSTNAME="$dhcp_hostname"
        log_info "Detected hostname from DHCP: $HOSTNAME"
    elif [ "$AUTO_INSTALL" = true ]; then
        log_error "Auto-install enabled but no hostname detected!"
        exit 1
    else
        echo "Unable to detect hostname from DHCP."
        echo "Please select the target host:"
        echo "1) n100-01"
        echo "2) n100-02"
        echo "3) n100-03"
        echo "4) n100-04"
        read -r -p "Enter selection (1-4): " selection
        case $selection in
            1) HOSTNAME="n100-01" ;;
            2) HOSTNAME="n100-02" ;;
            3) HOSTNAME="n100-03" ;;
            4) HOSTNAME="n100-04" ;;
            *) log_error "Invalid selection"; exit 1 ;;
        esac
    fi
}

# Detect installation disk
detect_disk() {
    log_info "Detecting installation disk..."
    
    # Look for NVMe drives first
    mapfile -t DISKS < <(lsblk -dno NAME,TYPE | grep disk | grep -E '(nvme|sd)' | awk '{print "/dev/"$1}')
    
    if [ ${#DISKS[@]} -eq 0 ]; then
        log_error "No suitable disks found!"
        exit 1
    elif [ ${#DISKS[@]} -eq 1 ]; then
        INSTALL_DISK="${DISKS[0]}"
        log_info "Found single disk: $INSTALL_DISK"
    else
        if [ "$AUTO_INSTALL" = true ]; then
            # In auto mode, use the first disk
            INSTALL_DISK="${DISKS[0]}"
            log_warn "Multiple disks found, auto-selecting first disk: $INSTALL_DISK"
        else
            log_warn "Multiple disks found:"
            for i in "${!DISKS[@]}"; do
                size=$(lsblk -dno SIZE "${DISKS[$i]}")
                echo "$((i+1))) ${DISKS[$i]} ($size)"
            done
            read -r -p "Select disk (1-${#DISKS[@]}): " selection
            INSTALL_DISK="${DISKS[$((selection-1))]}"
        fi
    fi
    
    # Confirm disk selection
    log_warn "Selected disk: $INSTALL_DISK"
    lsblk "$INSTALL_DISK"
    
    if [ "$AUTO_INSTALL" = true ]; then
        log_warn "Auto-install mode: proceeding without confirmation"
        log_warn "Installing to $INSTALL_DISK in 5 seconds..."
        sleep 5
    else
        read -r -p "This will DESTROY all data on $INSTALL_DISK. Continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_error "Installation cancelled"
            exit 1
        fi
    fi
}

# Apply disko configuration
apply_disko_config() {
    log_info "Applying disko configuration for ZFS setup..."
    
    # Generate host ID if needed
    if [ ! -f /etc/hostid ]; then
        zgenhostid
    fi
    
    # Clone the configuration to get the disko module
    TEMP_CONFIG="/tmp/nixos-config"
    rm -rf "$TEMP_CONFIG"
    git clone https://github.com/jamesbrink/nixos.git "$TEMP_CONFIG"
    
    # Create a temporary disko configuration that uses the detected disk
    cat > /tmp/disko-config.nix << EOF
{
  imports = [ $TEMP_CONFIG/modules/n100-disko.nix ];
  
  # Override the disk device to use our detected disk
  disko.devices.disk.main.device = "$INSTALL_DISK";
}
EOF
    
    # Run disko to format and mount the disk
    log_info "Running disko to format disk $INSTALL_DISK..."
    disko --mode disko /tmp/disko-config.nix
    
    # Verify the pool was created
    if ! zpool list "$POOL_NAME" &>/dev/null; then
        log_error "ZFS pool creation failed!"
        exit 1
    fi
    
    log_info "Disko formatting completed successfully"
}

# Generate host-specific configuration
generate_config() {
    log_info "Generating NixOS configuration for $HOSTNAME..."
    
    # Copy the configuration we already cloned
    mkdir -p "$MOUNT_POINT/etc/nixos"
    cp -r /tmp/nixos-config/* "$MOUNT_POINT/etc/nixos/"
    cd "$MOUNT_POINT/etc/nixos"
    
    # Generate unique host ID for ZFS
    HOST_ID=$(head -c 8 /dev/urandom | od -A n -t x8 | tr -d ' \n' | cut -c 1-8)
    
    # Create hardware configuration
    nixos-generate-config --root "$MOUNT_POINT"
    
    # Update host ID in configuration
    sed -i "s/networking.hostId = \".*\";/networking.hostId = \"$HOST_ID\";/" \
        "hosts/$HOSTNAME/default.nix" || true
}

# Install NixOS
install_nixos() {
    log_info "Installing NixOS..."
    
    # Set up channels
    nix-channel --add https://nixos.org/channels/nixos-25.05 nixos
    nix-channel --update
    
    # Install
    nixos-install \
        --no-root-password \
        --flake ".#$HOSTNAME" \
        --root "$MOUNT_POINT"
}

# Main installation flow
main() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║               N100 Automated NixOS Installer                  ║
║                    ZFS Root Configuration                     ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    
    # Check kernel parameters first
    check_kernel_params
    
    # Run installation steps
    detect_hostname
    detect_disk
    
    log_info "Starting installation for $HOSTNAME on $INSTALL_DISK"
    
    apply_disko_config
    generate_config
    install_nixos
    
    # Success message
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║                  Installation Complete!                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  NixOS has been successfully installed on $HOSTNAME.
║                                                               ║
║  The system will reboot in 10 seconds.                        ║
║  Press Ctrl+C to cancel automatic reboot.                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    
    # Cleanup
    umount -R "$MOUNT_POINT" || true
    zpool export "$POOL_NAME" || true
    
    # Reboot
    sleep 10
    reboot
}

# Run main function
main "$@"
