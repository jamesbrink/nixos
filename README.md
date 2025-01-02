# NixOS Configuration

This repository contains my personal NixOS configurations managed through the Nix Flakes system. It provides a reproducible and declarative setup for multiple machines with shared configurations and modules.

## Overview

This project uses:
- Nix Flakes for reproducible builds and dependency management
- Multi-host configuration with a mix of stable (24.11) and unstable channels
- Home Manager for user environment management
- Agenix for secrets management
- VSCode Server support for remote development
- Modular configuration structure for better maintainability

## Project Structure

```
.
├── README.md
├── flake.lock
├── flake.nix        # Main flake configuration and input sources
├── hosts/           # Host-specific configurations
│   ├── hal9000/     # Configuration for hal9000 machine
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   ├── n100-01/     # Configuration for n100-01 machine
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── n100-03/     # Configuration for n100-03 machine
│       ├── default.nix
│       └── hardware-configuration.nix
├── modules/         # Shared NixOS modules
│   ├── desktop/     # Desktop environment configurations
│   ├── packages/    # Custom package definitions
│   │   └── ollama
│   │       ├── default.nix
│   │       ├── disable-git.patch
│   │       └── skip-rocm-cp.patch
│   ├── services/    # System service configurations
│   ├── shared-packages/ # Common package sets
│   │   ├── default.nix
│   │   └── devops.nix
│   └── system/      # Core system configurations
├── profiles/        # Reusable system profiles
│   ├── desktop
│   │   ├── default-stable.nix
│   │   └── default.nix
│   ├── minimal
│   └── server
│       └── default.nix
└── users/          # User-specific configurations
    ├── regular
    │   └── jamesbrink.nix
    └── root
```

## Quick Start

### Deploy to a Host

To deploy to a specific host (e.g., n100-01):

```shell
nixos-rebuild switch --fast --flake .#n100-01 --target-host n100-01 --build-host n100-01 --use-remote-sudo
```

### Adding a New Host

1. Create a new directory under `hosts/` with your hostname
2. Add your host-specific configuration in `hosts/your-hostname/default.nix`
3. Add your host to the `nixosConfigurations` in `flake.nix`

## Module System

The configuration is organized into several module categories:
- `desktop`: Desktop environment configurations
- `packages`: Custom package definitions and overlays
- `services`: System service configurations
- `shared-packages`: Common package sets used across hosts
- `system`: Core system configurations

## User Management

User configurations are managed through Home Manager and stored in the `users/` directory. This provides a way to maintain consistent user environments across different hosts.

## Secrets Management

Secrets are managed using Agenix and stored in a separate private repository. The secrets repository is referenced as an input in the flake configuration.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This configuration is built on top of the excellent work by the NixOS community and various module maintainers.
