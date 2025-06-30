# NixOS Configuration

This repository contains my personal NixOS configurations managed through the Nix Flakes system. It provides a reproducible and declarative setup for multiple machines with shared configurations and modules.

## Overview

This project uses:
- Nix Flakes for reproducible builds and dependency management
- Multi-host configuration with NixOS 25.05 (stable) and unstable channels
- Home Manager for user environment management
- Agenix for secrets management (stored in a separate private repository)
- VSCode Server support for remote development
- Modular configuration structure for better maintainability
- Claude Desktop and other AI development tools

## Project Structure

```
.
├── CLAUDE.md        # AI assistant guidance and documentation
├── LICENSE          # MIT License
├── README.md        # This file
├── flake.lock       # Locked dependencies
├── flake.nix        # Main flake configuration
├── treefmt.toml     # Code formatting configuration
├── hosts/           # Host-specific configurations
│   ├── alienware/   # Desktop workstation
│   ├── hal9000/     # Main server with AI services
│   ├── n100-01/     # Cluster node 1
│   ├── n100-03/     # Cluster node 3
│   ├── n100-04/     # Cluster node 4
│   └── sevastopol/  # 2013 iMac 27"
├── modules/         # Shared modules and services
│   ├── packages/    # Custom package definitions
│   │   ├── ollama/  # Ollama AI model runner
│   │   └── postgis-reset/
│   ├── services/    # Service configurations
│   │   ├── ai-starter-kit/  # n8n/qdrant/postgres integration
│   │   └── postgresql/
│   └── shared-packages/     # Common package sets
│       ├── agenix.nix
│       ├── default.nix
│       └── devops.nix
├── pkgs/           # Custom package builds
│   └── llama-cpp/  # CUDA-enabled llama.cpp
├── profiles/       # Reusable system profiles
│   ├── desktop/    # Desktop environment (stable/unstable)
│   ├── keychron/   # Keyboard configuration
│   └── server/     # Server profile
└── users/          # User configurations
    └── regular/
        ├── jamesbrink.nix
        └── strivedi.nix
```

## Hosts

- **alienware**: Desktop workstation with NVIDIA GPU support
- **hal9000**: Main server running AI services (Ollama, ComfyUI, etc.)
- **n100-01, n100-03, n100-04**: Intel N100 cluster nodes
- **sevastopol**: 2013 iMac 27" desktop system

## Development Shell

The project includes a comprehensive development shell with categorized commands:

### Development Commands
- `format` - Format all files using treefmt (nixfmt for .nix, prettier for web files)
- `check` - Check Nix expressions for errors (runs `nix flake check --impure`)

### Deployment Commands
- `deploy <hostname>` - Deploy configuration to a host (auto-detects local/remote)
- `deploy-test <hostname>` - Test deployment without making changes (dry-activate)
- `build <hostname>` - Build configuration without deploying
- `update` - Update all NixOS and flake inputs
- `update-input <input>` - Update a specific flake input

### Maintenance Commands
- `show-hosts` - List all available hosts
- `health-check <hostname>` - Check system health (disk, memory, services, errors)
- `gc <hostname>` - Run garbage collection on a host
- `show-generations <hostname>` - Show NixOS generations on a host
- `rollback <hostname>` - Roll back to the previous generation

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

### Adding a New Host

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