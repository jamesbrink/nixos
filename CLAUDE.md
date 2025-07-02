# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Commands
- `format`: Format all files using treefmt (`nixfmt` for .nix, `prettier` for HTML/CSS/JS/JSON)
- `check`: Check Nix expressions for errors (runs `nix flake check --impure`)

### Deployment Commands
- `deploy <hostname>`: Deploy configuration to a host (automatically detects local vs remote)
- `deploy-local <hostname>`: Build locally and deploy to a remote host (useful for low-RAM targets)
- `deploy-test <hostname>`: Test deployment without making changes (dry-activate)
- `build <hostname>`: Build configuration for a host without deploying
- `update`: Update all NixOS and flake inputs
- `update-input <input-name>`: Update a specific flake input

### Maintenance Commands
- `show-hosts`: List all available hosts
- `health-check <hostname>`: Check system health (disk, memory, services, errors)
- `gc <hostname>`: Run garbage collection on a host
- `show-generations <hostname>`: Show NixOS generations on a host
- `rollback <hostname>`: Roll back to the previous generation

## High-Level Architecture

### Repository Structure
The codebase follows a modular NixOS/nix-darwin flake structure with clear separation of concerns:

```
.
├── hosts/                 # Host-specific configurations
│   ├── alienware/        # Gaming desktop (Linux)
│   ├── hal9000/          # Main server with AI services (Linux)
│   ├── halcyon/          # M4 Mac (Darwin)
│   ├── n100-01..04/      # Cluster nodes (Linux)
│   ├── sevastopol/       # 2013 iMac 27" (Darwin)
│   └── sevastopol-linux/ # 2013 iMac 27" dual-boot (Linux)
├── modules/              # Custom modules and services
│   ├── darwin/           # macOS-specific modules
│   ├── packages/         # Custom package definitions
│   ├── services/         # Service configurations
│   ├── shared-packages/  # Shared package sets
│   └── claude-desktop.nix # Claude desktop config
├── pkgs/                 # Custom package derivations
│   └── llama-cpp/        # LLaMA C++ implementation
├── profiles/             # Reusable system profiles
│   ├── darwin/           # macOS base profiles
│   ├── desktop/          # Linux desktop environments
│   ├── keychron/         # Keyboard-specific settings
│   └── server/           # Server configurations
├── secrets/              # Encrypted secrets (agenix)
│   ├── global/           # Shared secrets
│   └── secrets.nix       # Age recipients configuration
├── users/                # User configurations
│   └── regular/          # Regular user accounts
├── flake.nix            # Flake definition
├── flake.lock           # Pinned dependencies
├── treefmt.toml         # Code formatting config
└── CLAUDE.md            # This file
```

1. **Flake Configuration** (`flake.nix`):
   - Defines all external inputs (nixpkgs stable/unstable, home-manager, agenix, vscode-server, darwin, nix-homebrew)
   - Configures development shell with all deployment and maintenance commands
   - Defines NixOS configurations for Linux hosts and darwinConfigurations for macOS hosts
   - Supports both x86_64-linux and aarch64-darwin (Apple Silicon) architectures

2. **Host Configurations** (`hosts/*/`):
   - Each host has its own directory with `default.nix` and hardware configuration
   - Hosts import shared profiles, modules, and user configurations
   - Linux hosts: `hal9000` (main server with AI services), `n100-*` (cluster nodes), `alienware` (desktop), `sevastopol`
   - macOS hosts: `halcyon` (M4 Mac)

3. **Profiles** (`profiles/*/`):
   - Reusable system profiles (desktop, server, keychron, darwin)
   - Linux desktop profile includes GNOME, development tools, and remote access
   - Darwin profiles include macOS-specific settings, Homebrew integration, and dock management
   - Profiles can have stable and unstable variants

4. **Modules** (`modules/*/`):
   - Custom services (ai-starter-kit for n8n/qdrant/postgres integration)
   - Shared package sets (default.nix, devops.nix)
   - Darwin-specific modules (dock management, Homebrew packages)
   - Service configurations with proper NixOS/nix-darwin module patterns
   - Claude desktop configuration deployment (claude-desktop.nix)

5. **User Management** (`users/*/`):
   - Per-user configurations with home-manager integration
   - Supports both stable and unstable package channels per user
   - Cross-platform user module with conditional logic for Linux vs Darwin
   - Includes user-specific packages, dotfiles, and shell configurations

### Key Architectural Patterns

1. **Channel Management**:
   - Stable channel (nixos-25.05) as default
   - Unstable overlay available via `pkgs.unstablePkgs`
   - Per-host channel selection based on requirements

2. **Secrets Management**:
   - Uses agenix for encrypted secrets
   - Secrets stored in separate private repository
   - Age identity from host SSH keys

3. **Container Services**:
   - Podman for containerized services (PostgreSQL, Ollama, ComfyUI, etc.)
   - Custom AI service stack with automatic updates
   - Network isolation with podman networks

4. **Storage Architecture**:
   - ZFS for advanced storage features on main servers
   - NFS exports for shared storage across network
   - Bind mounts for service-specific storage paths

## Code Style Guidelines

- Use `nixfmt-rfc-style` formatter for all Nix files
- Follow 2-space indentation consistently
- Structure imports with hardware-configuration first, then modules, then users
- Use attribute sets for related configuration options
- Prefer `mkOption` with proper types and descriptions for custom modules
- Always include `--impure` flag with Nix commands due to unfree packages
- Use descriptive names for options, following NixOS naming conventions
- Separate stable and unstable package usage clearly
- Document non-obvious configuration choices with comments

## Development Workflow

1. Make changes to relevant files
2. Run `format` to ensure consistent formatting
3. Run `check` to validate Nix expressions
4. Use `build <hostname>` to test build locally
5. Use `deploy-test <hostname>` to dry-run deployment
6. Use `deploy <hostname>` to apply changes
7. If issues occur, use `rollback <hostname>` to revert

## Important Notes

- All deployment commands automatically handle local vs remote execution
- Remote deployments use rsync to copy flake before building
- The development shell includes all necessary tools for maintenance
- NIXPKGS_ALLOW_UNFREE=1 is set automatically in deployment commands
- Host configurations can mix stable and unstable packages via overlays
- Darwin hosts use nix-darwin instead of nixos-rebuild for system management
- macOS deployments require Determinate Nix (nix.enable = false in darwin configs)
- Homebrew is integrated for GUI applications not available in nixpkgs
- Alacritty is installed via Nix packages (not Homebrew) on Darwin
- Terminal applications use MesloLGS Nerd Font (not "MesloLGS NF")
- The `thefuck` package has been replaced with `pay-respects` (aliases: `fuck`, `pr`)

## Package Configuration Notes

### DataGrip Database IDE
- **Darwin**: Installed via Homebrew cask in `profiles/darwin/desktop.nix`
- **Linux**: Installed via `jetbrains.datagrip` package in `users/regular/jamesbrink-linux.nix`
- Available on all systems where jamesbrink user is configured

## Known Issues and Solutions

### Alacritty Terminal Definition Error
If you see "can't find terminal definition for alacritty":
- The terminfo file is manually installed to `~/.terminfo/a/alacritty`
- Future deployments will automatically handle this via activation scripts
- Terminal applications should use `TERM=alacritty` (not xterm-256color)

### Ollama Installation on macOS
- Ollama is installed via Homebrew cask as `ollama-app` (not `ollama`)
- The CLI is automatically linked to `/opt/homebrew/bin/ollama`
- Start the Ollama app from Applications before using the CLI

## Workflow Recommendations
- Always use `deploy-test` over `build` when on macOS

## Recent Architecture Changes

### Claude Desktop Configuration (June 2025)
- Added automatic deployment of Claude desktop configuration across all hosts
- Configuration is stored as an encrypted secret using agenix
- Deploys to `/Library/Application Support/Claude/` on Darwin hosts
- Deploys to `~/.config/Claude/` on Linux hosts
- Uses activation scripts with proper platform-specific handling

### Agenix Integration Improvements (June 2025)
- Fixed agenix package to use flake input directly, avoiding Nix builds from source
- Updated all secrets commands to support both id_rsa and id_ed25519 SSH keys
- Improved secrets path structure in secrets.nix for better clarity
- Enhanced secrets commands with better error handling and path normalization

### User Module Refactoring (December 2024)
- Refactored user modules to fix infinite recursion issues
- Split user configurations into platform-specific files:
  - `jamesbrink.nix`: Linux-only wrapper that imports `jamesbrink-linux.nix`
  - `jamesbrink-darwin.nix`: macOS-specific configuration (imported directly by Darwin hosts)
  - `jamesbrink-linux.nix`: Linux-specific configuration (imported via `jamesbrink.nix`)
  - `jamesbrink-shared.nix`: Shared configuration imported by both platform configs
- Host configurations import the appropriate user module:
  - Linux hosts: Import `jamesbrink.nix`
  - Darwin hosts: Import `jamesbrink-darwin.nix` directly
- Fixed conditional imports to prevent circular dependencies
- Improved cross-platform compatibility with proper platform detection

### Secrets Path Handling in User Modules (July 2025)
- Fixed AWS secrets path resolution issues during remote deployments
- User modules now accept `secretsPath` as a function argument with fallback logic
- Ensures secrets can be found regardless of whether building locally or remotely
- AWS secrets are configured in `users/regular/jamesbrink-linux.nix` with proper path handling

### Darwin (macOS) Support
- Full support for Apple Silicon Macs (tested on M4)
- Integration with Homebrew for GUI applications via nix-homebrew
- Custom dock management module for automatic dock configuration
- Separate package sets for Darwin vs Linux systems
- Platform-specific service configurations

### Alacritty Terminal Fixes (July 2025)
- Fixed "can't find terminal definition for alacritty" errors on Darwin
- Changed Alacritty TERM from "alacritty" to "xterm-256color" for compatibility
- Added zsh initialization to handle terminfo lookup and backspace key fixes
- Moved `option_as_alt` setting to correct window section in Alacritty config
- Removed non-functional terminfo activation script

## Secrets Management Process
- Secrets are managed using agenix
- Stored as a git submodule in `secrets/` (private repository)
- Each host's SSH key must be added as a recipient in `secrets/secrets.nix`
- Re-encrypt secrets after adding new recipients using `secrets-rekey` command

### Secrets Path Resolution
- The secrets input is defined as `path:./secrets` in the flake
- During local builds, `secretsPath` is set to `${inputs.secrets}` which resolves to the nix store path
- During remote deployments, the flake and secrets are copied to `/tmp/nixos-config/` on the target host
- User modules handle path resolution with fallback logic:
  - First tries the `secretsPath` argument passed from host configuration
  - Falls back to `config._module.args.secretsPath` if available
  - Finally falls back to `"./secrets"` for remote deployments
- All secret file paths follow the pattern: `${secretsPath}/secrets/<category>/<name>.age`
- The double `secrets` in the path is intentional: `secretsPath` points to the repository root, and `secrets/` is the subdirectory containing encrypted files

### Secrets Management Commands
- `secrets-edit <path>`: Create or edit a secret (e.g., `secrets-edit jamesbrink/syncthing-password`)
- `secrets-list`: List all available secrets
- `secrets-rekey`: Re-encrypt all secrets with current recipients
- `secrets-verify`: Verify all secrets can be decrypted
- `secrets-sync`: Pull latest changes from the secrets submodule
- `secrets-add-host <hostname>`: Get SSH key for a new host to add to recipients
- `secrets-print <path>`: Decrypt and print a secret for testing/debugging (e.g., `secrets-print global/claude-desktop-config`)

**Note**: Secrets commands now support both `~/.ssh/id_rsa` and `~/.ssh/id_ed25519` keys, preferring `id_rsa` when available.

### Adding a New Host to Secrets
1. Run `secrets-add-host <hostname>` to get the host's SSH key
2. Add the key to `secrets/secrets.nix` in the host keys section
3. Add the host to all relevant `publicKeys` arrays
4. Run `secrets-rekey` to re-encrypt all secrets
5. Commit and push changes in the secrets submodule

### Security Notes
- Never commit plaintext secrets to the repository
- The secrets submodule is private and should remain so
- Syncthing passwords are now managed at the host level, not in user configs
- Webhook tokens and API keys should be moved to encrypted secrets