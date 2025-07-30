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
├── CLAUDE.md                    # AI assistant guidance and documentation
├── docs/                        # Documentation files
│   └── nix-darwin-trackpad-options.md  # macOS trackpad configuration options
├── flake.lock                   # Locked dependencies
├── flake.nix                    # Main flake configuration
├── hosts/                       # Host-specific configurations
│   ├── alienware/               # Desktop workstation (NixOS)
│   ├── darkstarmk6mod1/         # MacBook Pro 16" 2019 (Darwin)
│   ├── hal9000/                 # Main server with AI services (NixOS)
│   ├── halcyon/                 # M4 Mac (Darwin)
│   ├── n100-01/                 # Cluster node 1 (NixOS)
│   ├── n100-02/                 # Cluster node 2 (NixOS)
│   ├── n100-03/                 # Cluster node 3 (NixOS)
│   ├── n100-04/                 # Cluster node 4 (NixOS)
│   └── sevastopol/              # Intel iMac 27" 2013 (Darwin)
├── LICENSE                      # MIT License
├── modules/                     # Shared modules and services
│   ├── aws-root-config.nix      # AWS configuration for root user
│   ├── claude-desktop.nix       # Claude desktop config deployment
│   ├── darwin/                  # Darwin-specific modules
│   │   ├── dock.nix             # Dock configuration
│   │   ├── file-sharing.nix     # macOS file sharing config
│   │   └── packages.nix         # Darwin packages
│   ├── ghostty-terminfo.nix     # Ghostty terminal support
│   ├── heroku-cli.nix           # Heroku CLI module
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
│   │   └── postgis-reset/       # PostGIS webhook handler
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
│   ├── ssh-keys.nix             # SSH key management
│   └── unified-shell-experience.nix # Unified shell environment
├── overlays/                    # Nix overlays
│   └── README.md                # Overlays documentation
├── pkgs/                        # Custom package builds
│   ├── llama-cpp/               # CUDA-enabled llama.cpp
│   └── netboot-xyz/             # Netboot.xyz package
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
├── README.md                    # This file
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
├── SECRETS.md                   # Secrets management documentation
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

## Hosts

### NixOS Hosts

- **alienware**: Desktop workstation with NVIDIA GPU support
- **hal9000**: Main server running AI services (Ollama, ComfyUI, etc.)
- **n100-01, n100-02, n100-03, n100-04**: Intel N100 cluster nodes

### Darwin (macOS) Hosts

- **halcyon**: M4 Mac with Apple Silicon
- **sevastopol**: Intel iMac 27" 2013 running macOS Sequoia via OCLP
- **darkstarmk6mod1**: 2019 MacBook Pro 16" Intel

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

   ```
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

```
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

### Channel Management

- Stable channel (nixos-25.05) as default
- Unstable overlay available via `pkgs.unstablePkgs`
- Per-host channel selection based on requirements

### Unified Shell Experience

- Consistent shell environment across all hosts and users (including root)
- Tmux with Ctrl+B prefix key, vi-mode, and clipboard integration
- Zsh with oh-my-zsh, starship prompt, and modern CLI replacements
- Neovim with LSP support, treesitter, and gruvbox-material theme
- Managed through `modules/unified-shell-experience.nix`

### AWS Configuration Management

- Centralized AWS config for root user across all hosts
- Configuration matches jamesbrink user's AWS setup
- Managed through `modules/aws-root-config.nix`
- Supports multiple AWS profiles and regions

### Container Services

- Podman for containerized services
- Custom AI service stack with automatic updates
- Network isolation with podman networks

### Storage Architecture

- ZFS for advanced storage features on main servers
- NFS exports for shared storage across network
- Bind mounts for service-specific storage paths
- PostgreSQL ZFS snapshot management with webhook-based reset functionality

### Backup System

- Automated Restic backups to AWS S3 for all hosts
- Each host has its own repository in S3 bucket `urandom-io-backups`
- Linux hosts: Daily automatic backups via systemd timer
- Darwin hosts: Daily backups at 2 AM via launchd + manual backup script
- Default backup paths:
  - Linux: `/etc/nixos`, `/home`, `/root`, `/var/lib`
  - Darwin: `~/Documents`, `~/Projects`, `~/.config`, `~/.ssh`
- Retention policy: 7 daily, 4 weekly, 12 monthly, 2 yearly snapshots
- Compression enabled with automatic exclusion of cache/temp files

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

| Host                | Mount Point             | NFS Server | Remote Path           | Options                                                     |
| ------------------- | ----------------------- | ---------- | --------------------- | ----------------------------------------------------------- |
| **halcyon**         | `/mnt/NFS-*`            | Various    | All available exports | noowners, nolockd, noresvport, hard, bg, intr, rw, tcp, nfc |
| **sevastopol**      | `/mnt/NFS-*`            | Various    | All available exports | noowners, nolockd, noresvport, hard, bg, intr, rw, tcp, nfc |
| **darkstarmk6mod1** | `/opt/nfs-mounts/NFS-*` | Various    | All available exports | noowners, nolockd, noresvport, hard, bg, intr, rw, tcp, nfc |

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

- **macOS hosts** (halcyon, sevastopol, darkstarmk6mod1):

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
