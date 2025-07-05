#!/usr/bin/env bash
set -euo pipefail

# Build and deploy netboot images for N100 cluster
# This script should be run from the nixos repository root

# Handle script running from nix store vs local directory
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" == /nix/store/* ]]; then
    # Running from nix develop - find the actual repo location
    REPO_ROOT="${NIX_CONFIG_DIR:-$PWD}"
    # If we're not in the repo, try to find it
    if [ ! -f "$REPO_ROOT/flake.nix" ]; then
        REPO_ROOT="$(pwd)"
        while [ ! -f "$REPO_ROOT/flake.nix" ] && [ "$REPO_ROOT" != "/" ]; do
            REPO_ROOT="$(dirname "$REPO_ROOT")"
        done
    fi
else
    # Running locally
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

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

log_info "Building N100 netboot images..."

# Create a temporary directory for build results
BUILD_DIR=$(mktemp -d /tmp/netboot-build.XXXXXX)
trap "rm -rf $BUILD_DIR" EXIT

# Build installer image
log_info "Building installer image..."
# Change to temp directory to avoid store path issues
cd "$BUILD_DIR"
INSTALLER_PATH=$(nix build "path:$REPO_ROOT?dir=modules/netboot#n100-installer" --impure --print-out-paths)
if [ $? -eq 0 ] && [ -n "$INSTALLER_PATH" ]; then
    log_info "Installer image built successfully"
    # Create symlink for consistency
    ln -sf "$INSTALLER_PATH" "$BUILD_DIR/installer-result"
else
    log_error "Failed to build installer image"
    log_error "Error: $INSTALLER_PATH"
    exit 1
fi

# Resolve the actual build output path
INSTALLER_RESULT="$(readlink -f "$BUILD_DIR/installer-result")"

# Check what was actually built
if [ -f "$INSTALLER_RESULT/kernel" ]; then
    # Direct output format
    INSTALLER_KERNEL="$INSTALLER_RESULT/kernel"
    INSTALLER_INITRD="$INSTALLER_RESULT/initrd"
    if [ -f "$INSTALLER_RESULT/system-path" ]; then
        INSTALLER_SYSTEM="$(cat "$INSTALLER_RESULT/system-path")"
    else
        log_error "system-path file not found in installer result"
        exit 1
    fi
else
    log_error "Expected kernel file not found in build result"
    log_error "Build result path: $INSTALLER_RESULT"
    log_error "Build result contains:"
    ls -la "$INSTALLER_RESULT/" >&2
    exit 1
fi

# Build rescue image
log_info "Building rescue image..."
# Build using print-out-paths to get the actual store path (already in BUILD_DIR)
RESCUE_PATH=$(nix build "path:$REPO_ROOT?dir=modules/netboot#n100-rescue" --impure --print-out-paths)
if [ $? -eq 0 ] && [ -n "$RESCUE_PATH" ]; then
    log_info "Rescue image built successfully"
    # Create symlink for consistency
    ln -sf "$RESCUE_PATH" "$BUILD_DIR/rescue-result"
else
    log_error "Failed to build rescue image"
    log_error "Error: $RESCUE_PATH"
    exit 1
fi

# Resolve the actual build output path
RESCUE_RESULT="$(readlink -f "$BUILD_DIR/rescue-result")"

# Check what was actually built
if [ -f "$RESCUE_RESULT/kernel" ]; then
    # Direct output format
    RESCUE_KERNEL="$RESCUE_RESULT/kernel"
    RESCUE_INITRD="$RESCUE_RESULT/initrd"
    if [ -f "$RESCUE_RESULT/system-path" ]; then
        RESCUE_SYSTEM="$(cat "$RESCUE_RESULT/system-path")"
    else
        log_error "system-path file not found in rescue result"
        exit 1
    fi
else
    log_error "Expected kernel file not found in build result"
    log_error "Build result path: $RESCUE_RESULT"
    log_error "Build result contains:"
    ls -la "$RESCUE_RESULT/" >&2
    exit 1
fi

# Debug output
log_info "Build results:"
log_info "  Installer kernel: $(basename "$INSTALLER_KERNEL")"
log_info "  Installer system: $INSTALLER_SYSTEM"
log_info "  Rescue kernel: $(basename "$RESCUE_KERNEL")"
log_info "  Rescue system: $RESCUE_SYSTEM"

# Auto-deploy without prompting
log_info "Deploying to HAL9000..."

# Deploy to HAL9000
log_info "Deploying netboot images to HAL9000..."

NETBOOT_ROOT="/export/storage-fast/netboot"
SSH_HOST="hal9000"

# Create directory structure
log_info "Creating directory structure on HAL9000..."
ssh "$SSH_HOST" "sudo mkdir -p $NETBOOT_ROOT/images/{n100-installer,n100-rescue} $NETBOOT_ROOT/custom $NETBOOT_ROOT/scripts"

# Deploy installer
log_info "Deploying installer image..."
TEMP_PREFIX="/tmp/netboot-$$-$(date +%s)"
scp "$INSTALLER_KERNEL" "$SSH_HOST:${TEMP_PREFIX}-kernel-installer"
scp "$INSTALLER_INITRD" "$SSH_HOST:${TEMP_PREFIX}-initrd-installer"
ssh "$SSH_HOST" "sudo mv ${TEMP_PREFIX}-kernel-installer $NETBOOT_ROOT/images/n100-installer/kernel"
ssh "$SSH_HOST" "sudo mv ${TEMP_PREFIX}-initrd-installer $NETBOOT_ROOT/images/n100-installer/initrd"

# Save init path for installer (remove leading slash for netboot)
log_info "Saving installer init path..."
INSTALLER_INIT_PATH="${INSTALLER_SYSTEM#/}/init"
ssh "$SSH_HOST" "echo '$INSTALLER_INIT_PATH' | sudo tee $NETBOOT_ROOT/images/n100-installer/init-path > /dev/null"

# Deploy rescue
log_info "Deploying rescue image..."
scp "$RESCUE_KERNEL" "$SSH_HOST:${TEMP_PREFIX}-kernel-rescue"
scp "$RESCUE_INITRD" "$SSH_HOST:${TEMP_PREFIX}-initrd-rescue"
ssh "$SSH_HOST" "sudo mv ${TEMP_PREFIX}-kernel-rescue $NETBOOT_ROOT/images/n100-rescue/kernel"
ssh "$SSH_HOST" "sudo mv ${TEMP_PREFIX}-initrd-rescue $NETBOOT_ROOT/images/n100-rescue/initrd"

# Save init path for rescue (remove leading slash for netboot)
log_info "Saving rescue init path..."
RESCUE_INIT_PATH="${RESCUE_SYSTEM#/}/init"
ssh "$SSH_HOST" "echo '$RESCUE_INIT_PATH' | sudo tee $NETBOOT_ROOT/images/n100-rescue/init-path > /dev/null"

# Deploy auto-install script
log_info "Deploying auto-install script..."
scp "$NETBOOT_DIR/auto-install.sh" "$SSH_HOST:${TEMP_PREFIX}-auto-install.sh"
ssh "$SSH_HOST" "sudo mkdir -p $NETBOOT_ROOT/scripts && sudo mv ${TEMP_PREFIX}-auto-install.sh $NETBOOT_ROOT/scripts/auto-install.sh"

# Update TFTP iPXE scripts with correct init paths
log_info "Updating TFTP iPXE scripts with correct init paths..."
# First update any placeholder patterns
ssh "$SSH_HOST" "sudo find $NETBOOT_ROOT/tftp -name '*.ipxe' -exec sed -i 's|/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-nixos-system-installer/init|$INSTALLER_SYSTEM/init|g' {} \;"
# Also update any existing nix store paths for the installer
ssh "$SSH_HOST" "sudo find $NETBOOT_ROOT/tftp -name '*.ipxe' -exec sed -i 's|/nix/store/[a-z0-9]\{32\}-nixos-system-nixos-installer[^/]*/init|$INSTALLER_SYSTEM/init|g' {} \;"

# Create a custom autochain.ipxe file with the correct init path
log_info "Creating custom autochain.ipxe with correct init path..."
ssh "$SSH_HOST" "sudo tee $NETBOOT_ROOT/custom/autochain.ipxe > /dev/null" << 'EOF'
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
kernel ${base-url}/images/n100-installer/kernel init=/INSTALLER_INIT_PATH initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=${hostname} autoinstall=true
initrd ${base-url}/images/n100-installer/initrd
boot || goto failed

:failed
echo Boot failed for ${hostname}
prompt Press any key to return to menu...
exit 1
EOF

# Replace the placeholder with the actual init path (without leading slash)
ssh "$SSH_HOST" "sudo sed -i 's|INSTALLER_INIT_PATH|$INSTALLER_INIT_PATH|g' $NETBOOT_ROOT/custom/autochain.ipxe"

# Create cmdline.ipxe files for dynamic loading
log_info "Creating cmdline.ipxe files for dynamic init paths..."

# Installer cmdline.ipxe
ssh "$SSH_HOST" "sudo tee $NETBOOT_ROOT/images/n100-installer/cmdline.ipxe > /dev/null" << EOF
#!ipxe
# Dynamic kernel command line for N100 installer
kernel \${base-url}/images/n100-installer/kernel init=$INSTALLER_INIT_PATH initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0 hostname=\${hostname}
initrd \${base-url}/images/n100-installer/initrd
boot
EOF

# Rescue cmdline.ipxe
ssh "$SSH_HOST" "sudo tee $NETBOOT_ROOT/images/n100-rescue/cmdline.ipxe > /dev/null" << EOF
#!ipxe
# Dynamic kernel command line for N100 rescue
kernel \${base-url}/images/n100-rescue/kernel init=$RESCUE_INIT_PATH initrd=initrd loglevel=4 console=ttyS0,115200 console=tty0
initrd \${base-url}/images/n100-rescue/initrd
boot
EOF

# Set permissions
log_info "Setting permissions..."
ssh "$SSH_HOST" "sudo chmod -R 755 $NETBOOT_ROOT/images $NETBOOT_ROOT/scripts $NETBOOT_ROOT/custom"
ssh "$SSH_HOST" "sudo chown -R nginx:nginx $NETBOOT_ROOT/images $NETBOOT_ROOT/scripts $NETBOOT_ROOT/custom"

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