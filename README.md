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

## Project Structure

```
.
├── .envrc           # Direnv configuration
├── .gitignore       # Git ignore rules
├── .gitmodules      # Git submodules (secrets)
├── CLAUDE.md        # AI assistant guidance and documentation
├── CLAUDE.local.md  # Local development notes (not in repo)
├── LICENSE          # MIT License
├── README.md        # This file
├── SECRETS.md       # Secrets management documentation
├── flake.lock       # Locked dependencies
├── flake.nix        # Main flake configuration
├── treefmt.toml     # Code formatting configuration
├── hosts/           # Host-specific configurations
│   ├── alienware/   # Desktop workstation (NixOS)
│   ├── hal9000/     # Main server with AI services (NixOS)
│   ├── halcyon/     # M4 Mac (Darwin)
│   ├── n100-01/     # Cluster node 1 (NixOS)
│   ├── n100-03/     # Cluster node 3 (NixOS)
│   ├── n100-04/     # Cluster node 4 (NixOS)
│   ├── sevastopol/  # Intel iMac 27" 2013 (Darwin)
│   └── sevastopol-linux/  # Intel iMac dual-boot (NixOS)
├── modules/         # Shared modules and services
│   ├── darwin/      # Darwin-specific modules
│   │   ├── dock.nix # Dock configuration
│   │   └── packages.nix  # Darwin packages
│   ├── packages/    # Custom package definitions
│   │   ├── ollama/  # Ollama AI model runner
│   │   └── postgis-reset/  # PostGIS webhook handler
│   ├── services/    # Service configurations
│   │   ├── ai-starter-kit/  # n8n/qdrant/postgres integration
│   │   └── postgresql/      # PostgreSQL with PostGIS
│   ├── shared-packages/     # Common package sets
│   │   ├── agenix.nix       # Age encryption tools
│   │   ├── default.nix      # Default packages
│   │   ├── devops.nix       # DevOps tools
│   │   └── devops-darwin.nix # Darwin DevOps tools
│   └── claude-desktop.nix   # Claude desktop config deployment
├── pkgs/           # Custom package builds
│   └── llama-cpp/  # CUDA-enabled llama.cpp
├── profiles/       # Reusable system profiles
│   ├── darwin/     # Darwin profiles
│   │   ├── default.nix  # Base Darwin configuration
│   │   └── desktop.nix  # Darwin desktop profile
│   ├── desktop/    # NixOS desktop environment
│   │   ├── stable.nix   # Stable channel desktop
│   │   └── unstable.nix # Unstable channel desktop
│   ├── keychron/   # Keyboard configuration
│   └── server/     # Server profile
│       ├── stable.nix   # Stable server profile
│       └── unstable.nix # Unstable server profile
├── secrets/        # Encrypted secrets (git submodule)
└── users/          # User configurations
    └── regular/
        ├── jamesbrink.nix         # Main user entry point
        ├── jamesbrink-darwin.nix  # Darwin-specific config
        ├── jamesbrink-linux.nix   # Linux-specific config
        ├── jamesbrink-shared.nix  # Shared user config
        ├── strivedi.nix           # Additional user
        └── ssh/                   # SSH configurations
```

## Hosts

### NixOS Hosts
- **alienware**: Desktop workstation with NVIDIA GPU support
- **hal9000**: Main server running AI services (Ollama, ComfyUI, etc.)
- **n100-01, n100-03, n100-04**: Intel N100 cluster nodes
- **sevastopol-linux**: Intel iMac 27" 2013 dual-boot (Linux side)

### Darwin (macOS) Hosts
- **halcyon**: M4 Mac with Apple Silicon
- **sevastopol**: Intel iMac 27" 2013 running macOS Sequoia via OCLP

## Development Shell

The project includes a comprehensive development shell with categorized commands:

### Development Commands
- `format` - Format all files using treefmt (nixfmt for .nix, prettier for web files)
- `check` - Check Nix expressions for errors (runs `nix flake check --impure`)

### Deployment Commands
- `deploy <hostname>` - Deploy configuration to a host (auto-detects local/remote, Darwin/NixOS)
- `deploy-local <hostname>` - Build locally and deploy to remote (useful for low-RAM targets)
- `deploy-test <hostname>` - Test deployment without making changes (dry-activate)
- `build <hostname>` - Build configuration without deploying
- `update` - Update all NixOS and flake inputs
- `update-input <input>` - Update a specific flake input

### Maintenance Commands
- `show-hosts` - List all available hosts
- `health-check <hostname>` - Check system health (disk, memory, services, errors)
- `gc <hostname>` - Run garbage collection on a host
- `show-generations <hostname>` - Show system generations on a host
- `rollback <hostname>` - Roll back to the previous generation

### Secrets Commands
- `secrets-edit <path>` - Create or edit a secret (e.g., `secrets-edit jamesbrink/syncthing-password`)
- `secrets-list` - List all available secrets
- `secrets-rekey` - Re-encrypt all secrets with current recipients
- `secrets-verify` - Verify all secrets can be decrypted
- `secrets-sync` - Pull latest changes from the secrets submodule
- `secrets-add-host <hostname>` - Get SSH key for a new host to add to recipients

**Note**: All secrets commands support both `~/.ssh/id_rsa` and `~/.ssh/id_ed25519` keys (preferring id_rsa).

## Quick Start

### Enter Development Shell
```bash
nix develop
```

### Deploy to a Host
```bash
# Deploy to a specific host
deploy alienware

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

Secrets are managed using agenix and stored in a separate private repository:
- Repository: `git@github.com:jamesbrink/nix-secrets.git`
- Each host's SSH key must be added to `secrets.nix`
- Re-encrypt secrets after adding new recipients: `agenix -r`

## Key Features

### Channel Management
- Stable channel (nixos-25.05) as default
- Unstable overlay available via `pkgs.unstablePkgs`
- Per-host channel selection based on requirements

### Container Services
- Podman for containerized services
- Custom AI service stack with automatic updates
- Network isolation with podman networks

### Storage Architecture
- ZFS for advanced storage features on main servers
- NFS exports for shared storage across network
- Bind mounts for service-specific storage paths

### Claude Desktop Configuration
- Automatic deployment of Claude desktop settings across all hosts
- Configuration stored as encrypted agenix secret
- Deploys to platform-specific locations:
  - Darwin: `/Library/Application Support/Claude/`
  - Linux: `~/.config/Claude/`
- Managed through activation scripts with proper permissions

### Darwin (macOS) Support
- Full nix-darwin integration for declarative macOS configuration
- Homebrew integration via nix-homebrew for GUI applications
- Automatic dock configuration and management
- Support for both Intel and Apple Silicon Macs
- Seamless integration with existing NixOS infrastructure

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

### Development Tips

- Always use `--impure` flag due to unfree packages
- Run `format` before committing changes
- Use `deploy-test` before actual deployment
- Check CLAUDE.md for AI-assisted development guidelines

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built on the excellent work by the NixOS community and various module maintainers.