#!/usr/bin/env bash
set -euo pipefail

# Setup k3s agent on Arch Linux
# Usage: ./setup-k3s-arch.sh <hostname> <k3s-token>

HOSTNAME="${1:-}"
K3S_TOKEN="${2:-}"
SERVER_URL="https://hal9000.home.urandom.io:6443"
MAX_PODS="110"

if [[ -z "$HOSTNAME" ]] || [[ -z "$K3S_TOKEN" ]]; then
    echo "Usage: $0 <hostname> <k3s-token>"
    exit 1
fi

echo "Setting up k3s agent on $HOSTNAME..."

# Install k3s using official installer
echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Create k3s config directory
echo "Creating k3s config directory..."
sudo mkdir -p /etc/rancher/k3s

# Write k3s config
echo "Writing k3s config..."
sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
server: ${SERVER_URL}
token: ${K3S_TOKEN}
node-name: ${HOSTNAME}
kubelet-arg:
  - "max-pods=${MAX_PODS}"
  - "node-status-update-frequency=5s"
EOF

# Set proper permissions
sudo chmod 600 /etc/rancher/k3s/config.yaml

# Stop and disable default k3s.service
echo "Setting up k3s-agent service..."
sudo systemctl stop k3s.service 2>/dev/null || true
sudo systemctl disable k3s.service 2>/dev/null || true

# Create k3s-agent service file
sudo tee /etc/systemd/system/k3s-agent.service > /dev/null <<'EOFS'
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/%N.env
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service 2>/dev/null'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s agent

[Install]
WantedBy=multi-user.target
EOFS

# Reload systemd and enable k3s-agent
sudo systemctl daemon-reload
sudo systemctl enable k3s-agent
sudo systemctl start k3s-agent

echo ""
echo "Waiting for k3s to start..."
sleep 10

# Check status
echo ""
echo "k3s-agent status:"
sudo systemctl status k3s-agent --no-pager || true

echo ""
echo "Setup complete! Check node status with:"
echo "  kubectl get nodes"
