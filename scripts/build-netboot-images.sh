#!/usr/bin/env bash
set -euo pipefail

# Build and deploy netboot images for N100 cluster
# This script should be run from the nixos repository root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NETBOOT_DIR="$REPO_ROOT/modules/netboot"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "$REPO_ROOT/flake.nix" ]; then
    log_error "This script must be run from the nixos repository root"
    exit 1
fi

cd "$NETBOOT_DIR"

log_info "Building N100 netboot images..."

# Build installer image
log_info "Building installer image..."
if nix build .#n100-installer --impure; then
    log_info "Installer image built successfully"
else
    log_error "Failed to build installer image"
    exit 1
fi

# Save installer paths
INSTALLER_KERNEL="$(readlink -f result/kernel)"
INSTALLER_INITRD="$(readlink -f result/initrd)"
INSTALLER_SYSTEM="$(cat result/system-path)"

# Build rescue image
log_info "Building rescue image..."
if nix build .#n100-rescue --impure; then
    log_info "Rescue image built successfully"
else
    log_error "Failed to build rescue image"
    exit 1
fi

# Save rescue paths
RESCUE_KERNEL="$(readlink -f result/kernel)"
RESCUE_INITRD="$(readlink -f result/initrd)"
RESCUE_SYSTEM="$(cat result/system-path)"

# Ask user if they want to deploy
read -p "Deploy images to HAL9000? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled. Images are available at:"
    log_info "  Installer: $INSTALLER_KERNEL, $INSTALLER_INITRD"
    log_info "  Rescue: $RESCUE_KERNEL, $RESCUE_INITRD"
    exit 0
fi

# Deploy to HAL9000
log_info "Deploying netboot images to HAL9000..."

NETBOOT_ROOT="/export/storage-fast/netboot"
SSH_HOST="hal9000"

# Create directory structure
log_info "Creating directory structure on HAL9000..."
ssh "$SSH_HOST" "mkdir -p $NETBOOT_ROOT/images/{n100-installer,n100-rescue} $NETBOOT_ROOT/custom"

# Deploy installer
log_info "Deploying installer image..."
scp "$INSTALLER_KERNEL" "$SSH_HOST:$NETBOOT_ROOT/images/n100-installer/kernel"
scp "$INSTALLER_INITRD" "$SSH_HOST:$NETBOOT_ROOT/images/n100-installer/initrd"

# Save init path for installer
log_info "Saving installer init path..."
ssh "$SSH_HOST" "echo '$INSTALLER_SYSTEM/init' > $NETBOOT_ROOT/images/n100-installer/init-path"

# Deploy rescue
log_info "Deploying rescue image..."
scp "$RESCUE_KERNEL" "$SSH_HOST:$NETBOOT_ROOT/images/n100-rescue/kernel"
scp "$RESCUE_INITRD" "$SSH_HOST:$NETBOOT_ROOT/images/n100-rescue/initrd"

# Save init path for rescue
log_info "Saving rescue init path..."
ssh "$SSH_HOST" "echo '$RESCUE_SYSTEM/init' > $NETBOOT_ROOT/images/n100-rescue/init-path"

# Deploy auto-install script
log_info "Deploying auto-install script..."
scp "$NETBOOT_DIR/auto-install.sh" "$SSH_HOST:$NETBOOT_ROOT/scripts/"

# Update TFTP iPXE scripts with correct init paths
log_info "Updating TFTP iPXE scripts with correct init paths..."
ssh "$SSH_HOST" "find $NETBOOT_ROOT/tftp -name '*.ipxe' -exec sed -i 's|/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-nixos-system-installer/init|$INSTALLER_SYSTEM/init|g' {} \;"

# Create a custom autochain.ipxe file with the correct init path
log_info "Creating custom autochain.ipxe with correct init path..."
ssh "$SSH_HOST" "cat > $NETBOOT_ROOT/custom/autochain.ipxe" << 'EOF'
#!ipxe

# N100 MAC Address Auto-detection and Boot
# This script is automatically loaded by netboot.xyz custom URL feature

echo N100 Auto-boot Detection Script
echo Checking MAC address: ${mac}

# N100-01
iseq ${mac} e0:51:d8:12:ba:97 && goto boot_n100_01 ||

# N100-02
iseq ${mac} e0:51:d8:13:04:50 && goto boot_n100_02 ||

# N100-03
iseq ${mac} e0:51:d8:13:4e:91 && goto boot_n100_03 ||

# N100-04
iseq ${mac} e0:51:d8:15:46:4e && goto boot_n100_04 ||

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
set base-url http://${next-server}:8079
echo Loading NixOS installer for ${hostname} (automatic installation)...
kernel ${base-url}/images/n100-installer/kernel init=INSTALLER_INIT_PATH initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=${hostname} autoinstall=true
initrd ${base-url}/images/n100-installer/initrd
boot || goto failed

:failed
echo Boot failed for ${hostname}
prompt Press any key to return to menu...
exit 1
EOF

# Replace the placeholder with the actual init path
ssh "$SSH_HOST" "sed -i 's|INSTALLER_INIT_PATH|$INSTALLER_SYSTEM/init|g' $NETBOOT_ROOT/custom/autochain.ipxe"

# Set permissions
log_info "Setting permissions..."
ssh "$SSH_HOST" "chmod -R 755 $NETBOOT_ROOT/images $NETBOOT_ROOT/scripts"

log_info "Deployment complete!"
log_info ""
log_info "Next steps:"
log_info "1. Ensure HAL9000 has the netboot server enabled in its configuration"
log_info "2. Run 'nixos-rebuild switch' on HAL9000 to activate the netboot server"
log_info "3. Configure your N100 machines to PXE boot from the network"
log_info "4. The machines should boot and display the installation menu"
log_info ""
log_info "Netboot server will be available at:"
log_info "  HTTP: http://hal9000:8079/"
log_info "  iPXE script: http://hal9000:8079/ipxe/boot.ipxe"