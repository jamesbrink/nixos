# NixOS Configuration

This repository contains my personal NixOS configurations managed through the Nix Flakes system. It provides a reproducible and declarative setup for multiple machines with shared configurations and modules.

## Overview

This project uses:

- Nix Flakes for reproducible builds and dependency management
- Multi-host configuration supporting both NixOS and Darwin (macOS)
- NixOS 25.05 (stable) and unstable channels
- Home Manager for user environment management
- Agenix for secrets management (stored in a separate private repository)
- VSCode Server support for remote development on NixOS hosts
- Nix-darwin for macOS system configuration
- Homebrew integration via nix-homebrew for macOS GUI applications
- Modular configuration structure for better maintainability
- Claude Desktop and other AI development tools
- Comprehensive security scanning with TruffleHog and GitLeaks
- Pre-commit hooks for code formatting and secret detection

## Project Structure

```shell
.
├── .envrc                       # direnv configuration
├── .gitleaks.toml               # GitLeaks configuration
├── .gitignore                   # Git ignore patterns
├── .gitmodules                  # Git submodules (secrets)
├── .mcp.json                    # MCP configuration
├── .pre-commit-config.yaml      # Pre-commit hooks configuration
├── CLAUDE.md                    # AI assistant guidance and documentation
├── LICENSE                      # MIT License
├── README.md                    # This file
├── SECRETS.md                   # Secrets management documentation
├── TODO.md                      # Project todo list
├── claude                       # Claude CLI wrapper
├── docs/                        # Documentation files
│   └── nix-darwin-trackpad-options.md  # macOS trackpad configuration options
├── flake.lock                   # Locked dependencies
├── flake.nix                    # Main flake configuration
├── hosts/                       # Host-specific configurations
│   ├── alienware/               # Desktop workstation (NixOS)
│   ├── hal9000/                 # Main server with AI services (NixOS)
│   ├── halcyon/                 # M4 Mac (Darwin)
│   ├── n100-01/                 # Cluster node 1 (NixOS)
│   ├── n100-02/                 # Cluster node 2 (NixOS)
│   ├── n100-03/                 # Cluster node 3 (NixOS)
│   ├── n100-04/                 # Cluster node 4 (NixOS)
│   └── sevastopol/              # Intel iMac 27" 2013 (Darwin)
├── modules/                     # Shared modules and services
│   ├── aws-root-config.nix      # AWS configuration for root user
│   ├── claude-desktop.nix       # Claude desktop config deployment
│   ├── darwin/                  # Darwin-specific modules
│   │   ├── dock.nix             # Dock configuration
│   │   ├── file-sharing.nix     # macOS file sharing config
│   │   └── packages.nix         # Darwin packages
│   ├── ghostty-terminfo.nix     # Ghostty terminal support
│   ├── heroku-cli.nix           # Heroku CLI module
│   ├── home-manager/            # Home Manager modules
│   │   ├── cli-tools.nix        # CLI tool configurations
│   │   ├── editor/              # Editor configurations
│   │   └── shell/               # Shell configurations
│   ├── local-hosts.nix          # Local hosts file configuration
│   ├── n100-disko.nix           # N100 disk configuration
│   ├── n100-network.nix         # N100 network configuration
│   ├── netboot/                 # Netboot infrastructure
│   │   ├── auto-install.sh      # Automated installation script
│   │   ├── flake.lock           # Netboot flake lock
│   │   ├── flake.nix            # Netboot flake config
│   │   ├── installer-ssh-keys.nix    # SSH keys for installer
│   │   └── n100-installer.nix   # Installer configuration
│   ├── nfs-mounts.nix           # NFS client configuration
│   ├── packages/                # Custom package definitions
│   │   ├── ollama/              # Ollama AI model runner
│   │   └── postgres13-reset/    # PostgreSQL 13 reset handler
│   ├── restic-backups.nix       # Restic backup configuration
│   ├── restic-shell-init.nix    # Restic shell initialization
│   ├── services/                # Service configurations
│   │   ├── ai-starter-kit/      # n8n/qdrant/postgres integration
│   │   ├── netboot-autochain.nix # Netboot auto-chain config
│   │   ├── netboot-configs.nix  # Netboot configurations
│   │   ├── netboot-server.nix   # Netboot server module
│   │   ├── postgresql/          # PostgreSQL with PostGIS
│   │   ├── tftp-server.nix      # TFTP server configuration
│   │   └── windows11-vm.nix     # Windows 11 VM service
│   ├── shared-packages/         # Common package sets
│   │   ├── agenix.nix           # Age encryption tools
│   │   ├── default.nix          # Default packages
│   │   ├── devops-darwin.nix    # Darwin DevOps tools
│   │   └── devops.nix           # DevOps tools
│   └── ssh-keys.nix             # SSH key management
├── overlays/                    # Nix overlays
│   └── README.md                # Overlays documentation
├── pkgs/                        # Custom package builds
│   ├── llama-cpp/               # CUDA-enabled llama.cpp
│   ├── netboot-xyz/             # Netboot.xyz package
│   └── pixinsight/              # PixInsight astronomy software
├── profiles/                    # Reusable system profiles
│   ├── darwin/                  # Darwin profiles
│   │   ├── default.nix          # Base Darwin configuration
│   │   └── desktop.nix          # Darwin desktop profile
│   ├── desktop/                 # NixOS desktop environment
│   │   ├── default-stable.nix   # Stable channel desktop
│   │   └── default.nix          # Unstable channel desktop
│   ├── keychron/                # Keyboard configuration
│   ├── n100/                    # N100 cluster profile
│   └── server/                  # Server profile
├── scripts/                     # Utility scripts
│   ├── build-netboot-images.sh  # Build netboot images
│   ├── check-large-files.sh     # Check for large files
│   ├── deploy-all.sh            # Deploy to all hosts in parallel
│   ├── deploy-local.sh          # Build locally, deploy remotely
│   ├── deploy-n100-local.sh     # Initial N100 deployment (local build)
│   ├── deploy-n100.sh           # Initial N100 deployment
│   ├── deploy-test.sh           # Test deployment (dry-run)
│   ├── deploy.sh                # Deploy configuration to host
│   ├── health-check.sh          # Check system health
│   ├── nix-gc.sh                # Run garbage collection
│   ├── restic-run.sh            # Manually trigger backup
│   ├── restic-snapshots.sh      # List backup snapshots
│   ├── restic-status.sh         # Check backup status
│   ├── rollback.sh              # Rollback to previous generation
│   ├── scan-gitleaks.sh         # GitLeaks secret scanner
│   ├── scan-secrets-history.sh  # TruffleHog history scanner
│   ├── scan-secrets-pre-commit.sh # Pre-commit secret scanner
│   ├── scan-secrets.sh          # TruffleHog scanner
│   ├── secrets-add-host.sh      # Add host to secrets
│   ├── secrets-edit.sh          # Edit encrypted secrets
│   ├── secrets-print.sh         # Decrypt and print secret
│   ├── secrets-rekey.sh         # Re-encrypt all secrets
│   ├── secrets-verify.sh        # Verify secrets integrity
│   ├── setup-n100-macs.sh       # Document N100 MACs
│   └── show-generations.sh      # Show system generations
├── secrets/                     # Encrypted secrets (git submodule)
├── treefmt.toml                 # Code formatting configuration
└── users/                       # User configurations
    └── regular/
        ├── jamesbrink-darwin.nix  # Darwin-specific config
        ├── jamesbrink-linux.nix   # Linux-specific config
        ├── jamesbrink-shared.nix  # Shared user config
        ├── jamesbrink.nix       # Main user entry point
        ├── ssh/                 # SSH configurations
        │   └── config.d/        # SSH config directory
        │       └── 00-local-hosts # Local hosts config
        └── strivedi.nix         # Additional user
```

## Infrastructure Overview

This repository manages a multi-host NixOS/nix-darwin infrastructure consisting of 8 hosts across Linux and macOS platforms, organized into three functional categories: servers, workstations, and cluster nodes.

### Linux Hosts (NixOS)

#### hal9000 - Primary Server with AI Services

**Role**: Main computational server and infrastructure hub

**Hardware**:

- x86_64 Intel-based system with NVIDIA GPU (CUDA enabled)
- 32GB swap, ZFS storage pool (`storage-fast`)

**Key Services**:

- AI/ML Stack: Ollama, Open-WebUI, Fooocus, n8n workflow automation
- Database: PostgreSQL 13 with PostGIS (port 5433)
- Storage: NFS/Samba server for network shares
- Networking: TFTP/HTTP netboot server for N100 cluster
- Virtualization: libvirtd, KVM/QEMU, Windows 11 VM support

**Network Role**: Central hub serving storage, AI services, and cluster management

#### alienware - Desktop Workstation

**Role**: High-performance gaming and development workstation

**Hardware**:

- x86_64 with dual GPUs (integrated + discrete NVIDIA)
- Multiple storage drives: primary ext4, 8TB USB storage

**Key Services**:

- Desktop Environment: GNOME with remote desktop
- Gaming: Steam with game streaming (Sunshine/Moonlight)
- Storage: NFS/Samba server for local shares
- Sync: Syncthing hub coordinating with N100 cluster
- Virtualization: libvirtd, Incus, VMware guest tools

**Network Role**: Primary desktop with shared storage, linked to cluster

#### N100 Cluster (n100-01 through n100-04)

**Role**: Distributed computing cluster nodes

**Architecture**:

- 4x Intel N100 compact systems with NVMe SSDs
- ZFS root filesystem with declarative disko partitioning
- PXE netboot deployment capability

**Services per Node**:

- Minimal system footprint for compute workloads
- NFS client mounts to hal9000 and alienware
- Samba shares for local network access
- Automated Restic backups

**Network Role**: Distributed compute nodes with centralized management

**MAC Addresses**:

- n100-01: `e0:51:d8:12:ba:97` (IP: 10.70.100.201)
- n100-02: `e0:51:d8:13:04:50` (IP: 10.70.100.202)
- n100-03: `e0:51:d8:13:4e:91` (IP: 10.70.100.203)
- n100-04: `e0:51:d8:15:46:4e` (IP: 10.70.100.204)

### Darwin (macOS) Hosts

#### halcyon - M4 Mac

**Role**: Modern Apple Silicon development machine

**Hardware**: Apple M4 (ARM/aarch64-darwin) with Rosetta support

**Key Features**:

- Full Homebrew integration for GUI applications
- NFS client to all infrastructure storage
- Development tools: VS Code, JetBrains, Ghostty terminal
- AI tools: Claude desktop, ChatGPT

**Network Role**: Modern development machine with infrastructure access

#### sevastopol - Intel iMac 27" (2013)

**Role**: Legacy Intel Mac with extended OS support

**Hardware**: Intel iMac 27" running macOS Sequoia via OpenCore Legacy Patcher

**Key Features**:

- Similar software stack to halcyon
- Full infrastructure NFS access
- Legacy hardware kept current with OCLP

**Network Role**: Functional legacy Mac connected to infrastructure

### Network Architecture

**Address Spaces**:

- Home Network: 10.70.100.0/24 (primary LAN)
- Tailscale VPN: 100.64.0.0/10 (remote access)
- VM Networks: 192.168.122.0/24 (libvirt on hal9000)

**Storage Topology**:

```
hal9000 (central hub)
  ├── ZFS storage-fast → NFS/Samba exports
  ├── 20TB ext4 secondary → NFS/Samba exports
  └── Serves: AI models, PostgreSQL, n8n, ollama, VMs

alienware (secondary hub)
  ├── 8TB USB storage → NFS/Samba exports
  ├── Internal data drive → NFS/Samba exports
  └── Syncthing coordinator

N100 Cluster
  ├── Local ZFS root pools
  └── NFS clients mounting hal9000 and alienware

Darwin Macs (halcyon, sevastopol)
  └── NFS clients with access to all infrastructure storage
```

## Key Services and Infrastructure

### Custom Service Modules

The infrastructure includes several custom service modules defined in `modules/services/`:

#### AI Starter Kit (`ai-starter-kit/`)

**Purpose**: Integrated workflow automation and AI vector database

**Components**:

- n8n workflow automation platform (port 5678)
- Qdrant vector database (port 6333)
- PostgreSQL 13 database for n8n state
- Automated health monitoring and cleanup

**Deployed on**: hal9000

#### Netboot Infrastructure

**Purpose**: PXE network booting for N100 cluster deployment

**Components**:

- TFTP Server (`tftp-server.nix`): Serves iPXE boot scripts (port 69)
- Netboot Server (`netboot-server.nix`): HTTP server for boot images (port 8079)
- Auto-Chain (`netboot-autochain.nix`): MAC-based automatic boot routing
- Netboot Configs (`netboot-configs.nix`): Configuration file generator

**Features**:

- MAC address-based node detection
- Automatic installer boot for recognized N100 nodes
- Integration with netboot.xyz v2.0.87
- Declarative ZFS partitioning via disko

**Deployed on**: hal9000

#### Windows 11 VM (`windows11-vm.nix`)

**Purpose**: Development VM with full Windows 11 support

**Features**:

- TPM 2.0 and UEFI for Windows 11 compatibility
- Nested virtualization (Hyper-V, WSL2, Docker Desktop)
- VirtIO drivers for optimized performance
- SPICE graphics for remote desktop
- Configurable resources (memory, vCPUs, disk size)

**Management Commands**:

- `win11-vm start/stop/status/console`

**Deployed on**: hal9000 (available via module)

#### Samba Server (`samba-server.nix`)

**Purpose**: Cross-platform file sharing

**Features**:

- SMB2/SMB3 protocol support (SMB1 disabled)
- macOS optimization with fruit VFS module
- Avahi/Bonjour discovery for macOS
- WSDD for Windows 10/11 discovery
- NTLMv2 authentication only

**Deployed on**: All Linux hosts (hal9000, alienware, N100 cluster)

### Containerized Services (hal9000)

The following services run as Podman containers on hal9000:

| Service           | Port  | Purpose                               | GPU    |
| ----------------- | ----- | ------------------------------------- | ------ |
| **Ollama**        | 11434 | LLM inference server                  | NVIDIA |
| **Open-WebUI**    | 3000  | Chat interface for Ollama             | No     |
| **Pipelines**     | 9099  | Extended functionality for Open-WebUI | No     |
| **Fooocus**       | 7865  | AI image generation                   | NVIDIA |
| **PostgreSQL 13** | 5433  | Database with PostGIS extension       | No     |

**Key Features**:

- Automatic container updates and management
- Persistent storage via bind mounts to ZFS datasets
- GPU passthrough for AI workloads
- Health monitoring and auto-restart

### Infrastructure Services

#### Storage Services

- **NFS Servers**: hal9000, alienware, N100 cluster
- **Samba Servers**: All Linux hosts
- **ZFS Management**: Automatic scrub, trim, snapshots
- **PostgreSQL ZFS Snapshots**: Automated WAL sync and base snapshots

#### Networking Services

- **Tailscale VPN**: Secure remote access on all hosts
- **Avahi/mDNS**: Service discovery and .local hostname resolution
- **systemd-networkd**: Advanced networking on server hosts
- **Bridge Networks**: VM connectivity on hal9000

#### Backup Services

- **Restic to S3**: All 7 hosts backup to AWS S3
  - Linux: Daily via systemd timers
  - Darwin: Daily at 2 AM via launchd
- **Retention**: 7 daily, 4 weekly, 12 monthly, 2 yearly
- **PostgreSQL Backups**: ZFS snapshots + WAL archiving

#### Monitoring and Management

- **pgweb**: Database browser UI (port 8081)
- **ZFS Monitor**: WebSocket service (port 9999)
- **Webhook Service**: Database management and automation
- **Health Checks**: Automated via deployment tools

### Service Distribution by Host

| Service Category    | hal9000 | alienware | N100s | Darwin |
| ------------------- | ------- | --------- | ----- | ------ |
| AI/ML Services      | ✓       | -         | -     | -      |
| NFS Server          | ✓       | ✓         | ✓     | -      |
| Samba Server        | ✓       | ✓         | ✓     | -      |
| NFS Client          | -       | ✓         | ✓     | ✓      |
| PostgreSQL          | ✓       | -         | -     | -      |
| Netboot (TFTP/HTTP) | ✓       | -         | -     | -      |
| Syncthing           | -       | ✓         | ✓     | -      |
| Restic Backups      | ✓       | ✓         | ✓     | ✓      |
| Tailscale VPN       | ✓       | ✓         | ✓     | ✓      |
| Desktop (GNOME)     | -       | ✓         | -     | Native |
| Virtualization      | ✓       | ✓         | -     | -      |

## Development Shell

Enter the development shell with `nix develop` to access all deployment and maintenance commands listed below.

### Development Commands

- `format` - Format all files using treefmt (nixfmt for .nix, prettier for web files)
- `check` - Check Nix expressions for errors (runs `nix flake check --impure`)

### Deployment Commands

- `deploy <hostname>` - Deploy configuration to a host (auto-detects local/remote, Darwin/NixOS)
- `deploy-all` - Deploy to all hosts in parallel with summary report (options: --quiet, --sequential, --max-jobs N, --dry-run, --skip HOSTS, --darwin-only, --linux-only)
- `deploy-local <hostname>` - Build locally and deploy to remote (useful for low-RAM targets)
- `deploy-test <hostname>` - Test deployment without making changes (dry-activate)
- `build <hostname>` - Build configuration without deploying
- `update` - Update all NixOS and flake inputs
- `update-input <input>` - Update a specific flake input

### Maintenance Commands

- `show-hosts` - List all available hosts
- `health-check <hostname>` - Check system health (disk, memory, services, errors)
- `nix-gc <hostname>` - Run garbage collection on a host
- `show-generations <hostname>` - Show system generations on a host
- `rollback <hostname>` - Roll back to the previous generation

### Netboot Commands

- `scripts/build-netboot-images.sh` - Build N100 installer and rescue images
- `scripts/setup-n100-macs.sh` - Document N100 MAC addresses for netboot configuration

### Secrets Commands

- `secrets-edit <path>` - Create or edit a secret (e.g., `secrets-edit jamesbrink/syncthing-password`)
- `secrets-list` - List all available secrets
- `secrets-rekey` - Re-encrypt all secrets with current recipients
- `secrets-verify` - Verify all secrets can be decrypted
- `secrets-sync` - Pull latest changes from the secrets submodule
- `secrets-add-host <hostname>` - Get SSH key for a new host to add to recipients
- `secrets-print <path>` - Decrypt and print a secret (for testing/debugging)

**Note**: All secrets commands support both `~/.ssh/id_ed25519` and `~/.ssh/id_rsa` keys (preferring ed25519).

### Security Commands

- `scan-secrets` - Scan for secrets using TruffleHog (use `--help` for options)
- `scan-secrets-history` - Deep scan git history for secrets
- `scan-gitleaks` - Scan using GitLeaks (use `--help` for options)
- `security-audit` - Run comprehensive security audit with all scanners
- `pre-commit-install` - Install git hooks for formatting and security
- `pre-commit-run` - Run all pre-commit hooks manually

### Backup Commands

- `restic-status` - Check Restic backup status on all hosts
- `restic-run <hostname>` - Manually trigger backup on a specific host
- `restic-snapshots <hostname>` - List snapshots for a host

#### Using Restic Directly

After deployment, both the `jamesbrink` user and `root` can use restic commands without specifying repository or password:

```bash
# List snapshots (works for both jamesbrink and root)
restic snapshots

# Manually run a backup (Darwin)
restic-backup backup

# Manually run a backup (Linux)
sudo systemctl start restic-backups-s3-backup.service
# or use the alias:
backup

# Browse files in a snapshot
restic ls latest
restic ls <snapshot-id>

# Mount snapshots as filesystem (requires FUSE)
mkdir /tmp/restic-mount
restic mount /tmp/restic-mount

# Restore files
restic restore latest --target /tmp/restored-files
restic restore <snapshot-id> --target /path/to/restore --include /home/user/specific/file

# Check repository integrity
restic check

# View repository statistics
restic stats

# Prune old snapshots (already aliased)
restic-prune
```

#### Shell Aliases

The following aliases are available for the jamesbrink user:

- `backup`: Run backup (uses restic-backup on Darwin, systemctl on Linux)
- `snapshots`: List snapshots
- `restic-check`: Check repository integrity
- `restic-restore`: Restore files
- `restic-mount`: Mount repository
- `restic-ls`: List files in snapshot
- `restic-cat`: Display file contents from snapshot
- `restic-diff`: Show differences between snapshots
- `restic-stats`: Show repository statistics
- `restic-prune`: Remove old snapshots according to retention policy

## Quick Start

### Enter Development Shell

```bash
nix develop
```

### Deploy to a Host

```bash
# Deploy to a specific host
deploy alienware

# Deploy to all hosts in parallel
deploy-all

# Deploy to all hosts with minimal output
deploy-all --quiet

# Deploy to all hosts sequentially
deploy-all --sequential

# Deploy only to Darwin (macOS) hosts
deploy-all --darwin-only

# Deploy only to Linux (NixOS) hosts
deploy-all --linux-only

# Skip specific hosts during deployment
deploy-all --skip hal9000,n100-04

# Combine options: deploy to Linux hosts except alienware
deploy-all --linux-only --skip alienware

# Test deployment first
deploy-test sevastopol

# Build without deploying
build hal9000
```

### Adding a New NixOS Host

1. Generate hardware configuration on the target machine:

   ```bash
   nixos-generate-config --dir /tmp/config
   ```

2. Create host directory and copy configuration:

   ```bash
   mkdir hosts/newhostname
   cp /tmp/config/* hosts/newhostname/
   ```

3. Update `hosts/newhostname/default.nix` to follow project patterns

4. Add host to `flake.nix`:

   ```nix
   newhostname = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     specialArgs = {
       inherit inputs agenix;
       secretsPath = "${inputs.secrets}";
     };
     modules = [
       home-manager.nixosModules.home-manager
       agenix.nixosModules.default
       ./hosts/newhostname/default.nix
     ];
   };
   ```

5. Set up SSH keys and add to secrets repository
6. Deploy: `deploy newhostname`

### Adding a New Darwin Host

1. Create host directory:

   ```bash
   mkdir hosts/newhostname
   ```

2. Copy from an existing Darwin host as template:

   ```bash
   cp hosts/halcyon/default.nix hosts/newhostname/
   cp hosts/halcyon/hardware.nix hosts/newhostname/
   ```

3. Update hostname in `hosts/newhostname/default.nix`

4. Add host to `flake.nix` under `darwinConfigurations`:

   ```nix
   newhostname = darwin.lib.darwinSystem {
     system = "aarch64-darwin"; # or "x86_64-darwin" for Intel
     specialArgs = {
       inherit inputs agenix;
       secretsPath = "${inputs.secrets}";
       unstablePkgs = import nixos-unstable {
         system = "aarch64-darwin"; # match system above
         config.allowUnfree = true;
       };
     };
     modules = [
       home-manager-unstable.darwinModules.home-manager
       agenix.darwinModules.default
       nix-homebrew.darwinModules.nix-homebrew
       # ... other modules
       ./hosts/newhostname/default.nix
     ];
   };
   ```

5. Configure passwordless sudo (see Initial Darwin Setup section)
6. Add SSH host key to secrets
7. Deploy: `deploy newhostname`

### Initial Darwin (macOS) Setup

For first-time deployment to a Darwin host, you need to configure passwordless sudo:

1. SSH into the Darwin host:

   ```bash
   ssh jamesbrink@hostname
   ```

2. Create a sudoers file for your user:

   ```bash
   sudo visudo -f /etc/sudoers.d/jamesbrink
   ```

3. Add this line:

   ```sudoers
   jamesbrink ALL=(ALL) NOPASSWD: ALL
   ```

4. Save and exit (`:wq` in vi)

5. Fix file permissions:

   ```bash
   sudo chmod 440 /etc/sudoers.d/jamesbrink
   ```

6. Verify configuration:

   ```bash
   sudo visudo -c
   ```

After this, remote deployments will work without password prompts.

## Secrets Management

Secrets are managed using agenix and stored in a separate private repository as a git submodule:

- Repository: `git@github.com:jamesbrink/nix-secrets.git` (submodule at `./secrets/`)
- Each host's SSH key must be added to `secrets/secrets.nix`
- Re-encrypt secrets after adding new recipients: `secrets-rekey`
- Secret files are stored in `secrets/secrets/` directory structure
- All secrets commands handle the nested directory structure automatically

## N100 Cluster Netboot Deployment

The repository includes a complete netboot infrastructure for provisioning N100 cluster nodes via PXE boot.

### Prerequisites

- HAL9000 server with the netboot configuration deployed
- N100 machines configured for PXE boot in BIOS
- Network connectivity between N100 nodes and HAL9000

### Initial N100 Deployment Steps (Order Matters!)

For first-time deployment of N100 nodes:

1. **Deploy HAL9000 first** to enable netboot services:

   ```bash
   deploy hal9000
   ```

2. **Build and deploy netboot images**:

   ```bash
   scripts/build-netboot-images.sh
   ```

3. **For initial installation** using nixos-anywhere (resource-constrained N100s):

   ```bash
   deploy-n100-local n100-01  # Builds locally, deploys remotely
   deploy-n100-local n100-02
   deploy-n100-local n100-03
   deploy-n100-local n100-04
   ```

4. **After initial installation**, use regular deploy:

   ```bash
   deploy n100-01  # Uses standard deployment
   ```

### Key Components

- **TFTP Server**: Serves hostname-based iPXE scripts (port 69)
- **Nginx HTTP Server**: Serves kernel/initrd images and MAC-based configs (port 8079)
- **Disko**: Declarative disk partitioning with ZFS support (see `modules/n100-disko.nix`)
- **Netboot Installer**: Custom NixOS installer with ZFS and disko support
- **Auto-install Script**: Automated installation using disko configuration
- **Automated Config Generation**: N100 node configurations are generated automatically from `services.netbootConfigs` in HAL9000's configuration

### Setting Up Netboot

1. **Deploy Netboot Server on HAL9000**

   ```bash
   deploy hal9000
   ```

   This enables TFTP server for PXE booting and configures nginx to serve netboot images.

2. **Build and Deploy Netboot Images**

   ```bash
   nix develop -c netboot-build
   # or directly:
   ./scripts/build-netboot-images.sh
   ```

   This builds installer and rescue images with ZFS support and deploys them to HAL9000.

3. **Configure N100 BIOS for PXE Boot**

   - Enter BIOS (F2 or DEL during boot)
   - Enable network boot/PXE boot
   - Set network boot as first boot priority

4. **Boot and Install**
   - Boot from network to see the N100 Boot Menu
   - Default: Boots from local disk after 20 seconds
   - Press 'n' for Network installer, 'r' for Rescue mode
   - In installer, run `n100-install` for automated installation
   - The script detects hostname, uses disko to configure ZFS, and installs NixOS

### Network Boot Process

```mermaid
N100 → DHCP Request → MikroTik Router
     ← IP + next-server (HAL9000) + netboot.xyz.efi ←
     → TFTP: Request netboot.xyz.efi →
     ← TFTP: netboot.xyz v2.0.87 ←
     → (Optional) Chain to auto-detect script →
     ← Auto-boot NixOS installer if N100 MAC detected ←
```

### Netboot URLs

- **Netboot Server**: `http://hal9000.home.urandom.io:8079/` or `http://netboot.home.urandom.io:8079/`
- **Auto-chain Script**: `http://hal9000.home.urandom.io:8079/custom/autochain.ipxe` (for netboot.xyz integration)
- **Boot Files**: `http://hal9000.home.urandom.io:8079/boot/` (MAC-based iPXE scripts)
- **Installer Image**: `http://hal9000.home.urandom.io:8079/images/n100-installer/`
- **Rescue Image**: `http://hal9000.home.urandom.io:8079/images/n100-rescue/`
- **Access restricted to**: `10.70.100.0/24` and `100.64.0.0/10` networks

### Automatic N100 Installation

The netboot infrastructure supports fully automatic installation:

1. **MAC-based boot files**: `01-e0-51-d8-XX-XX-XX.ipxe` files automatically load for N100 nodes
2. **Auto-chain with netboot.xyz**: Configure netboot.xyz to use custom URL `http://hal9000:8079/custom/autochain.ipxe`
3. **Automatic detection**: Script checks MAC address and auto-boots NixOS installer with `autoinstall=true`
4. **Unattended install**: Installer automatically partitions disk with ZFS and installs NixOS

### Troubleshooting Netboot

- **PXE not working**: Check BIOS settings and network connectivity
- **Installation fails**: Boot rescue mode, check with `lsblk` and `journalctl`
- **SSH access**: Use `ssh root@n100-XX` (keys pre-configured)

### N100 Cluster Nodes

Current N100 nodes and their MAC addresses:

- **n100-01**: `e0:51:d8:12:ba:97` (IP: 10.70.100.201)
- **n100-02**: `e0:51:d8:13:04:50` (IP: 10.70.100.202)
- **n100-03**: `e0:51:d8:13:4e:91` (IP: 10.70.100.203)
- **n100-04**: `e0:51:d8:15:46:4e` (IP: 10.70.100.204)

### Adding New N100 Nodes

1. Generate hostId: `head -c 8 /dev/urandom | od -A n -t x8`
2. Create host configuration in `hosts/n100-XX/`
3. Add to secrets recipients if needed
4. Get MAC address: `ssh root@n100-XX ip link show | grep -A1 'state UP' | grep link/ether`
5. Update the `services.netbootConfigs.nodes` configuration in `hosts/hal9000/default.nix` with the new node's MAC address
6. Update `modules/services/tftp-server.nix` and `modules/services/netboot-autochain.nix` for MAC detection
7. Deploy HAL9000 to generate the new config file: `deploy hal9000`
8. Rebuild netboot images if needed

## Key Features

### Modular Architecture

**Three-Layer Configuration System**:

1. **Profiles** (`profiles/`): Reusable system profiles (server, desktop, darwin, n100, keychron)
2. **Modules** (`modules/`): Feature-specific configurations (services, packages, users)
3. **Hosts** (`hosts/`): Host-specific customizations and hardware configs

**Benefits**:

- Consistent configuration across similar hosts
- Easy maintenance and updates
- Clear separation of concerns
- Platform-specific abstractions (Linux vs Darwin)

### Dual-Channel Package Management

- **Stable Channel** (nixos-25.05): Default for system packages
- **Unstable Overlay**: Available via `pkgs.unstablePkgs` for cutting-edge software
- **Per-Host Selection**: Hosts can choose stable or unstable based on needs
- **Specialized Overlays**: Custom packages for PixInsight, llama-cpp, netboot-xyz

**Usage Pattern**:

```nix
environment.systemPackages = with pkgs; [
  git                    # From stable channel
  unstablePkgs.llm       # From unstable channel
];
```

### Unified Shell Experience

Consistent shell environment across all hosts and users (including root):

**Terminal Stack**:

- **Shell**: Zsh with oh-my-zsh and modern completion
- **Prompt**: Starship with git integration
- **Multiplexer**: Tmux (Ctrl+B prefix, vi-mode, clipboard integration)
- **Editor**: Neovim with LSP support, treesitter, gruvbox-material theme

**Modern CLI Replacements**:

- `eza` (replaces ls) - Modern file listing
- `bat` (replaces cat) - Syntax-highlighted file viewing
- `fd` (replaces find) - Fast file searching
- `ripgrep` (replaces grep) - Blazing fast text search
- `procs` (replaces ps) - Modern process viewer
- `pay-respects` (replaces thefuck) - Command correction

**Home-Manager Integration**:

- Managed through `modules/home-manager/` modules
- Cross-platform support (identical on Linux and Darwin)
- Root user gets same environment with red-bold prompt

### Cross-Platform Support

**Platform Abstraction**:

- **NixOS** (Linux): Uses `nixpkgs.lib.nixosSystem` and `nixos-rebuild`
- **nix-darwin** (macOS): Uses `darwin.lib.darwinSystem` and `darwin-rebuild`
- **Unified Modules**: Shared modules work on both platforms with conditional logic

**macOS Integration**:

- Homebrew integration via nix-homebrew for GUI applications
- Automatic dock configuration and management
- Support for both Intel (x86_64) and Apple Silicon (aarch64)
- Determinate Nix compatibility (`nix.enable = false`)

**Conditional Configuration**:

```nix
lib.optionals pkgs.stdenv.isLinux [ linux-only-package ]
++ lib.optionals pkgs.stdenv.isDarwin [ macos-only-package ]
```

### Centralized Secrets Management

**Agenix Integration**:

- Secrets stored in private Git submodule (`git@github.com:jamesbrink/nix-secrets.git`)
- Age encryption using SSH keys as identity
- Per-host access control via SSH public keys
- Automatic deployment and decryption

**Supported Secrets**:

- SSH authorized keys
- AWS credentials and configs
- Heroku authentication tokens
- Database passwords
- API keys (Infracost, Claude, webhooks)
- Syncthing passwords
- Claude desktop configuration

**Secret Management Workflow**:

1. Create/edit: `secrets-edit <path>`
2. Re-encrypt: `secrets-rekey` (after adding new hosts)
3. Verify: `secrets-verify`
4. Deploy: Automatically handled during `deploy <hostname>`

### Infrastructure as Code

**Declarative Everything**:

- Host configurations in Nix (no manual setup)
- Service definitions with proper options
- User environments via home-manager
- Disk layouts via disko (N100 cluster)
- Network configs via systemd-networkd

**Deployment Automation**:

- Single command deployment: `deploy <hostname>`
- Parallel deployment: `deploy-all` (all hosts at once)
- Test before apply: `deploy-test <hostname>`
- Automatic rollback capability: `rollback <hostname>`
- Health monitoring: `health-check <hostname>`

**Netboot Provisioning**:

- PXE boot for bare-metal N100 deployment
- MAC address-based automatic detection
- Unattended installation with disko
- Declarative ZFS partitioning

### Container Services

**Podman-Based Services** (hal9000):

- Rootless containerization with systemd integration
- Automatic updates and health monitoring
- GPU passthrough for AI workloads (Ollama, Fooocus)
- Persistent storage via bind mounts to ZFS datasets
- Pod-based networking for service isolation

**AI/ML Stack**:

- Ollama: LLM inference with NVIDIA GPU
- Open-WebUI: Chat interface
- Pipelines: Extended functionality
- Fooocus: AI image generation
- n8n: Workflow automation

### Advanced Storage Architecture

**ZFS Features** (hal9000, N100 cluster):

- Automatic scrub and trim scheduling
- Snapshot management and rollback
- PostgreSQL-specific ZFS snapshots (WAL + base)
- Webhook-based database reset functionality
- Dataset-per-service organization

**Network Storage**:

- **NFS**: Linux-to-Linux, Linux-to-macOS
- **Samba**: Cross-platform (Linux/Windows/macOS)
- **Automount**: On-demand with 600s idle timeout
- **Bind Mounts**: Service-specific paths (e.g., `/export/*`)

**Storage Distribution**:

- hal9000: ZFS pool (storage-fast) + 20TB ext4
- alienware: 8TB USB + internal data drive
- N100 nodes: Local ZFS root + NFS client mounts
- Darwin: NFS clients mounting all infrastructure storage

### Comprehensive Backup System

**Restic to AWS S3**:

- All 7 hosts backup to individual S3 repositories
- Bucket: `urandom-io-backups`
- Repository per host: `s3:urandom-io-backups/<hostname>`

**Backup Schedule**:

- **Linux**: Daily via systemd timers
- **Darwin**: Daily at 2 AM via launchd

**Retention Policy**:

- 7 daily snapshots
- 4 weekly snapshots
- 12 monthly snapshots
- 2 yearly snapshots

**Backup Paths**:

- **Linux**: `/etc/nixos`, `/home`, `/root`, `/var/lib`
- **Darwin**: `~/Documents`, `~/Projects`, `~/.config`, `~/.ssh`

**Features**:

- Compression enabled
- Automatic cache/temp exclusion
- Shell initialization for easy commands
- Manual trigger via `restic-run <hostname>`
- Browse snapshots: `restic-snapshots <hostname>`

### Security Features

**Multi-Layer Security**:

1. **Pre-commit Hooks**: Automatic formatting and secret scanning
2. **TruffleHog**: Verified secret detection in git history
3. **GitLeaks**: Git-aware secret scanner with custom rules
4. **Comprehensive Audits**: `security-audit` command
5. **Encrypted Secrets**: All sensitive data via agenix

**Network Security**:

- Tailscale VPN for secure remote access
- Firewall rules on server hosts
- SSH key-based authentication only
- NTLMv2-only for Samba (no LM/NTLMv1)
- SMB1 disabled (SMB2/SMB3 only)

**Access Control**:

- Age-encrypted secrets with per-host keys
- SSH authorized keys centrally managed
- Samba user authentication
- Network restrictions (10.70.100.0/24, 100.64.0.0/10)

### NFS Shares Documentation

#### NFS Exports (Server Side)

| Host          | Export Path            | Allowed Networks              | Options                                                                                      |
| ------------- | ---------------------- | ----------------------------- | -------------------------------------------------------------------------------------------- |
| **alienware** | `/export`              | 10.70.100.0/24                | rw, fsid=0, no_subtree_check                                                                 |
|               | `/export/storage`      | 10.70.100.0/24                | rw, nohide, insecure, no_subtree_check                                                       |
|               | `/export/data`         | 10.70.100.0/24                | rw, nohide, insecure, no_subtree_check                                                       |
| **hal9000**   | `/export`              | 10.70.100.0/24, 100.64.0.0/10 | rw, fsid=0, no_subtree_check                                                                 |
|               | `/export/storage-fast` | 10.70.100.0/24, 100.64.0.0/10 | rw, nohide, insecure, no_subtree_check                                                       |
| **n100-01**   | `/export`              | 192.168.0.0/16, 10.0.0.0/8    | rw, sync, no_subtree_check, no_root_squash, insecure, all_squash (anonuid=1000, anongid=100) |
| **n100-02**   | `/export`              | 192.168.0.0/16, 10.0.0.0/8    | rw, sync, no_subtree_check, no_root_squash, insecure, all_squash (anonuid=1000, anongid=100) |
| **n100-03**   | `/export`              | 192.168.0.0/16, 10.0.0.0/8    | rw, sync, no_subtree_check, no_root_squash, insecure, all_squash (anonuid=1000, anongid=100) |
| **n100-04**   | `/export`              | 192.168.0.0/16, 10.0.0.0/8    | rw, sync, no_subtree_check, no_root_squash, insecure, all_squash (anonuid=1000, anongid=100) |

#### NFS Mounts (Client Side)

##### Linux Hosts (Automated via `modules/nfs-mounts.nix`)

All Linux hosts automatically mount all available NFS shares under `/mnt/nfs/`:

| Mount Point             | NFS Server                | Remote Path            | Available On                     |
| ----------------------- | ------------------------- | ---------------------- | -------------------------------- |
| `/mnt/nfs/storage`      | alienware.home.urandom.io | `/export/storage`      | All Linux hosts except alienware |
| `/mnt/nfs/data`         | alienware.home.urandom.io | `/export/data`         | All Linux hosts except alienware |
| `/mnt/nfs/storage-fast` | hal9000.home.urandom.io   | `/export/storage-fast` | All Linux hosts except hal9000   |
| `/mnt/nfs/n100-01`      | n100-01.home.urandom.io   | `/export`              | All Linux hosts except n100-01   |
| `/mnt/nfs/n100-02`      | n100-02.home.urandom.io   | `/export`              | All Linux hosts except n100-02   |
| `/mnt/nfs/n100-03`      | n100-03.home.urandom.io   | `/export`              | All Linux hosts except n100-03   |
| `/mnt/nfs/n100-04`      | n100-04.home.urandom.io   | `/export`              | All Linux hosts except n100-04   |

**Mount Options**: `noatime,noauto,x-systemd.automount,x-systemd.device-timeout=10,x-systemd.idle-timeout=600`

##### macOS Hosts (Automounter Configuration)

macOS hosts use the automounter to mount NFS shares. The mount points are configured to avoid conflicts with Finder's network browsing functionality:

| Host           | Mount Point  | NFS Server | Remote Path           | Options                                                     |
| -------------- | ------------ | ---------- | --------------------- | ----------------------------------------------------------- |
| **halcyon**    | `/mnt/NFS-*` | Various    | All available exports | noowners, nolockd, noresvport, hard, bg, intr, rw, tcp, nfc |
| **sevastopol** | `/mnt/NFS-*` | Various    | All available exports | noowners, nolockd, noresvport, hard, bg, intr, rw, tcp, nfc |

**Note**: NFS shares are mounted outside of `/Volumes` to prevent conflicts with Finder's ability to mount network shares via the GUI. The automounter configuration is managed through the host-specific `system.activationScripts`.

#### Storage Details

- **alienware** exports:
  - `/export/storage` → 8TB USB drive mounted at `/mnt/storage`
  - `/export/data` → Second internal drive mounted at `/mnt/data`
- **hal9000** exports:

  - `/export/storage-fast` → ZFS pool mounted at `/storage-fast`

- **n100 cluster** exports:

  - Each node exports `/export` directory for local network sharing
  - Configured for both private IP ranges (192.168.0.0/16 and 10.0.0.0/8)
  - Uses permissive permissions (777) with all_squash for easy access

- **macOS hosts** (halcyon, sevastopol):

  - Mount all available NFS shares to `/Volumes/NFS-*` for Finder visibility
  - Uses macOS native automounter with `/etc/auto_nfs` configuration
  - All shares appear with NFS- prefix in Finder sidebar

- **Linux NFS client configuration**:
  - Automated via `modules/nfs-mounts.nix` module
  - Included in both server and desktop profiles
  - Automatically filters out self-mounts (hosts don't mount their own exports)
  - Uses systemd mount and automount units for on-demand mounting
  - All mounts appear under `/mnt/nfs/` with descriptive names

All NFS mounts use automount with a 600-second idle timeout for better resource management.

### SMB/Samba Shares Documentation

All Linux hosts in the network provide SMB/CIFS file sharing alongside NFS for better compatibility with Windows and macOS clients.

#### SMB Configuration Features

- **Protocol**: SMB2 to SMB3 with macOS-optimized settings
- **Authentication**: User-based authentication (no guest access)
- **Discovery**: Avahi/Bonjour for macOS and WSDD for Windows 10/11
- **Networks**: Restricted to local network (10.70.100.0/24) and Tailscale (100.64.0.0/10)
- **macOS Optimization**: Full fruit VFS module support with proper configuration

#### SMB Shares by Host

| Host          | Share Name   | Path            | Description                | Valid Users |
| ------------- | ------------ | --------------- | -------------------------- | ----------- |
| **hal9000**   | export       | /export         | HAL9000 export root        | jamesbrink  |
|               | storage      | /storage-fast   | Fast storage array (alias) | jamesbrink  |
|               | storage-fast | /storage-fast   | Fast storage array         | jamesbrink  |
| **alienware** | export       | /export         | Export root directory      | jamesbrink  |
|               | storage      | /export/storage | 8TB USB storage            | jamesbrink  |
|               | data         | /export/data    | Data drive                 | jamesbrink  |
| **n100-01**   | export       | /export         | N100 shared storage        | jamesbrink  |
| **n100-02**   | export       | /export         | N100 shared storage        | jamesbrink  |
| **n100-03**   | export       | /export         | N100 shared storage        | jamesbrink  |
| **n100-04**   | export       | /export         | N100 shared storage        | jamesbrink  |

#### Connecting to SMB Shares

##### From macOS

1. **Via Finder**:

   - Open Finder → Network → Select host
   - Or press Cmd+K and enter: `smb://hostname` or `smb://hostname.local`

2. **Direct share access**:

   - `smb://hal9000/storage`
   - `smb://alienware/data`
   - `smb://n100-01/export`

3. **Credentials**:
   - Username: `jamesbrink`
   - Password: Set via `samba-add-user` command

##### From Windows

1. **Via File Explorer**:

   - Type `\\hostname\sharename` in address bar
   - Example: `\\hal9000\storage`

2. **Network discovery**:
   - Hosts should appear in Network neighborhood (WSDD enabled)

##### From Linux

```bash
# List available shares
smbclient -L hostname -U jamesbrink

# Mount a share
sudo mount -t cifs //hostname/sharename /mnt/point -o username=jamesbrink

# Using file manager
smb://hostname/sharename
```

#### SMB Security Features

- Minimum protocol: SMB2 (SMB1 disabled for security)
- NTLMv2 authentication only
- Encryption available (if_required mode)
- No anonymous/guest access allowed
- Network access restricted to local and VPN networks

#### Managing SMB Users

To add or update SMB user passwords:

```bash
# On the host or via development shell
samba-add-user [username]

# If no username provided, defaults to current user
samba-add-user
```

The `samba-add-user` script is available in the development shell and on all Linux hosts.

### Claude Desktop Configuration

- Automatic deployment of Claude desktop settings for the jamesbrink user
- Configuration stored as encrypted agenix secret (`secrets/global/claude-desktop-config.age`)
- Deploys to platform-specific locations:
  - Darwin: `/Users/jamesbrink/Library/Application Support/Claude/claude_desktop_config.json`
  - Linux: `/home/jamesbrink/.config/Claude/claude_desktop_config.json`
- Managed through activation scripts with proper permissions
- Includes MCP server configurations for various AI and development tools

### Darwin (macOS) Support

- Full nix-darwin integration for declarative macOS configuration
- Homebrew integration via nix-homebrew for GUI applications
- Automatic dock configuration and management
- Support for both Intel and Apple Silicon Macs
- Seamless integration with existing NixOS infrastructure

### Modular Shell Scripts

- All complex devShell commands extracted into standalone scripts in `scripts/`
- 18 shell scripts for deployment, maintenance, secrets, and backup operations
- Scripts maintain identical functionality while being easier to test and maintain
- Shellcheck integration for shell script linting and validation
- Proper error handling with `set -euo pipefail` in all scripts

## Custom Packages

### PixInsight Astronomy Software

PixInsight is a commercial astronomy image processing application that requires special handling due to its licensing and size.

#### Initial Setup

1. **Purchase/Download**: Obtain PixInsight from [pixinsight.com](https://pixinsight.com) (requires license)
2. **Download the Linux tar.xz file**: `PI-linux-x64-1.9.3-20250402-c.tar.xz`
3. **Add to Nix Store** (on the target host):
   ```bash
   nix-prefetch-url --type sha256 file:///path/to/PI-linux-x64-1.9.3-20250402-c.tar.xz
   ```

#### Permanent Cache Solution

To prevent the PixInsight file from being garbage collected:

1. **Create cache directory** (on HAL9000):

   ```bash
   sudo mkdir -p /var/cache/pixinsight
   sudo cp ~/Downloads/PI-linux-x64-*.tar.xz /var/cache/pixinsight/
   sudo chmod 644 /var/cache/pixinsight/*.tar.xz
   ```

2. **Add to Nix store**:
   ```bash
   nix-store --add-fixed sha256 /var/cache/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz
   ```

The cache directory is preserved via systemd tmpfiles rules and prevents repeated downloads.

#### Version Updates

When updating PixInsight:

1. Download new version from pixinsight.com
2. Copy to `/var/cache/pixinsight/`
3. Update version and hash in `pkgs/pixinsight/package.nix`
4. Rebuild the system

See `docs/pixinsight-cache.md` for detailed troubleshooting.

### Other Custom Packages

- **llama-cpp**: CUDA-enabled LLaMA implementation for AI workloads
- **netboot-xyz**: Custom netboot.xyz package (v2.0.87) for PXE booting

## Troubleshooting

### Common Issues

1. **Hash Mismatch Errors**

   - Update the affected input: `update-input <input-name>`
   - Or update all inputs: `update`

2. **Git Not Found on Fresh Install**

   - The target system needs git installed to fetch secrets
   - Consider manual bootstrap or temporary secrets bypass

3. **SSH Key Issues**

   - Ensure host SSH keys are added to secrets repository
   - Verify GitHub access from the target host

4. **macOS Restic Backup Permission Popups**
   - If you see security popups for `sh` or `bash` when restic runs
   - Solution: Grant Full Disk Access to `/bin/sh` and `/bin/bash`
   - Steps: System Preferences → Privacy & Security → Full Disk Access → Add both binaries
   - This is required because restic runs via launchd using shell scripts
   - The permission warnings in logs (FileProvider, Control Center) are normal and cannot be avoided

### Development Tips

- Always use `--impure` flag due to unfree packages
- Run `format` before committing changes
- Use `deploy-test` before actual deployment
- Check CLAUDE.md for AI-assisted development guidelines

## Security

This repository includes multiple layers of security to prevent accidental exposure of secrets:

### Pre-commit Hooks

Run `pre-commit-install` once to automatically enable:

- **Code Formatting**: Automatic formatting of Nix, JSON, YAML, and Markdown files
- **Secret Detection**: Both TruffleHog and GitLeaks scan for potential secrets before commit
- **File Size Limits**: Prevents commits of files larger than 5MB

### Security Scanning Tools

- **TruffleHog**: Detects verified secrets in git history and filesystem
- **GitLeaks**: Git-aware secret scanner with custom rules for Nix repositories
- **Comprehensive Audits**: `security-audit` runs all scanners in sequence

### Best Practices

- All sensitive data is encrypted using agenix in the `secrets/` submodule
- Secrets are never committed to the main repository
- Host-specific SSH keys control access to encrypted secrets
- Regular security audits using `security-audit` command

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built on the excellent work by the NixOS community and various module maintainers.
