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

## Features

- Multi-host configuration management
- Mix of stable (24.11) and unstable channels
- Integrated Home Manager for user environment management
- Secure secrets management with Agenix
- Remote development support with VSCode Server
- Modular configuration structure

## Dependencies

This configuration relies on several external inputs:
- nixpkgs (nixos-24.11)
- nixos-unstable
- home-manager (release-24.11)
- home-manager-unstable
- agenix
- vscode-server

## Quick Start

### Deploy to a Host

To deploy to a specific host (e.g., hal9000):

```shell
nixos-rebuild switch --fast --flake .#hal9000 --target-host hal9000 --build-host hal9000 --use-remote-sudo
```

For hosts requiring unfree packages:

```shell
sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake .#hal9000 --verbose --impure
```

### Development Workflow

1. **Local Testing**
   ```shell
   # Test configuration build without applying
   nixos-rebuild build --flake .#<hostname>
   
   # Test with fast compilation (development)
   nixos-rebuild build --flake .#<hostname> --fast
   ```

2. **Updating Dependencies**
   ```shell
   # Update all flake inputs
   nix flake update
   
   # Update specific input
   nix flake lock --update-input nixpkgs
   ```

3. **Working with Home Manager**
   ```shell
   # Apply home-manager configuration
   home-manager switch --flake .#<username>@<hostname>
   ```

## Contributing

1. **Fork and Clone**
   ```shell
   git clone https://github.com/jamesbrink/nixos.git
   cd nixos
   ```

2. **Branch Naming**
   - Use descriptive branch names: `feature/new-service`, `fix/broken-config`
   - Keep changes focused and atomic

3. **Commit Guidelines**
   - Write clear commit messages
   - Reference issues when applicable
   - Sign your commits

4. **Testing**
   - Test configurations locally before pushing
   - Ensure secrets are properly managed
   - Verify on all affected hosts

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check for dirty git working tree
   - Verify flake inputs are up-to-date
   - Ensure correct system architecture is targeted

2. **Remote Deployment Issues**
   - Verify SSH access to target host
   - Check sudo permissions
   - Ensure target host has sufficient resources

3. **Home Manager Conflicts**
   - Backup existing configurations
   - Remove conflicting dotfiles
   - Check for path conflicts

### Debug Tips

- Use `--show-trace` for detailed error information
- Enable verbose output with `-v` or `-vv`
- Check system journal for errors: `journalctl -xe`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

This configuration is built on top of the excellent work by the NixOS community and various module maintainers.
