#!/usr/bin/env bash
# Setup script for N100 MAC addresses
# This script creates placeholder MAC-based configuration files

set -euo pipefail

# Define N100 MAC addresses (from Terraform configuration)
declare -A N100_MACS=(
    ["n100-01"]="e0:51:d8:12:ba:97"
    ["n100-02"]="e0:51:d8:13:04:50"
    ["n100-03"]="e0:51:d8:13:4e:91"
    ["n100-04"]="e0:51:d8:15:46:4e"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}N100 MAC Address Setup Script${NC}"
echo "================================"
echo ""

echo "MAC Address Summary:"
echo "===================="
for host in "${!N100_MACS[@]}"; do
    echo "${host}: ${N100_MACS[$host]}"
done

# Create configuration files
echo ""
echo "Creating configuration files..."

# Create a simple YAML config for each MAC
for host in "${!N100_MACS[@]}"; do
    mac="${N100_MACS[$host]}"
    cat > "/tmp/${mac}.yaml" <<EOF
# N100 Configuration for ${host}
# MAC Address: ${mac}
---
hostname: ${host}
mac_address: ${mac}
install_options:
  disk: /dev/nvme0n1
  zfs_pool: rpool
  network:
    dhcp: true
EOF
    echo -e "${GREEN}Created config for ${host} (${mac})${NC}"
done

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Copy the generated configs to /export/storage-fast/netboot/configs/"
echo "   Example: sudo cp /tmp/*.yaml /export/storage-fast/netboot/configs/"
echo "2. Deploy the configuration to HAL9000: deploy hal9000"
echo "3. Test netboot with one of the N100 machines"