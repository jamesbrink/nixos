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
ssh "$SSH_HOST" "mkdir -p $NETBOOT_ROOT/images/{n100-installer,n100-rescue}"

# Deploy installer
log_info "Deploying installer image..."
scp "$INSTALLER_KERNEL" "$SSH_HOST:$NETBOOT_ROOT/images/n100-installer/kernel"
scp "$INSTALLER_INITRD" "$SSH_HOST:$NETBOOT_ROOT/images/n100-installer/initrd"

# Update iPXE script with correct init path
log_info "Updating iPXE script with installer init path..."
ssh "$SSH_HOST" "sed -i 's|init=/nix/store/.*-nixos-system-installer/init|init=$INSTALLER_SYSTEM/init|g' $NETBOOT_ROOT/ipxe/boot.ipxe"

# Deploy rescue
log_info "Deploying rescue image..."
scp "$RESCUE_KERNEL" "$SSH_HOST:$NETBOOT_ROOT/images/n100-rescue/kernel"
scp "$RESCUE_INITRD" "$SSH_HOST:$NETBOOT_ROOT/images/n100-rescue/initrd"

# Update iPXE script with correct init path
log_info "Updating iPXE script with rescue init path..."
ssh "$SSH_HOST" "sed -i 's|init=/nix/store/.*-nixos-system-rescue/init|init=$RESCUE_SYSTEM/init|g' $NETBOOT_ROOT/ipxe/boot.ipxe"

# Deploy auto-install script
log_info "Deploying auto-install script..."
scp "$NETBOOT_DIR/auto-install.sh" "$SSH_HOST:$NETBOOT_ROOT/scripts/"

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