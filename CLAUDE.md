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
- `deploy-n100-local <n100-hostname>`: Build locally and deploy to N100 nodes (for resource-constrained targets)

### Maintenance Commands
- `show-hosts`: List all available hosts
- `health-check <hostname>`: Check system health (disk, memory, services, errors)
- `nix-gc <hostname>`: Run garbage collection on a host
- `show-generations <hostname>`: Show NixOS generations on a host
- `rollback <hostname>`: Roll back to the previous generation

### Netboot Commands
- `scripts/build-netboot-images.sh`: Build N100 installer and rescue images
- `scripts/setup-n100-macs.sh`: Document N100 MAC addresses for netboot
- Test auto-chain: `curl http://hal9000:8079/custom/autochain.ipxe`
- View boot files: `curl http://hal9000:8079/boot/`

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
│   ├── netboot/          # Netboot installer and scripts
│   ├── packages/         # Custom package definitions
│   ├── services/         # Service configurations
│   ├── shared-packages/  # Shared package sets
│   ├── claude-desktop.nix # Claude desktop config
│   └── n100-disko.nix    # N100 ZFS disk configuration
├── pkgs/                 # Custom package derivations
│   ├── llama-cpp/        # LLaMA C++ implementation
│   └── netboot-xyz/      # Netboot.xyz bootloader package
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

### Ghostty Terminal Definition Error
If you see "can't find terminal definition for xterm-ghostty":
- **Linux hosts**: The `ghostty-terminfo` module is automatically enabled via user configuration
- **SSH connections**: Use `ghostty-ssh-setup <hostname>` to copy terminfo to remote hosts
- **Sudo environments**: TERMINFO variables are preserved automatically
- **Fallback**: The terminal will automatically fall back to `xterm-256color` if needed
- The zsh configuration includes automatic detection and fallback for Ghostty

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

### N100 Netboot Infrastructure (July 2025)
- Implemented complete PXE netboot infrastructure for N100 cluster nodes
- **Updated to netboot.xyz v2.0.87** with custom package in `pkgs/netboot-xyz/`
- Added disko support to netboot installer for declarative ZFS partitioning
- Created `modules/n100-disko.nix` with ZFS configuration (root, nix, var, home datasets + swap zvol)
- Updated `modules/netboot/auto-install.sh` to support automatic installation via kernel parameters
- Added `modules/netboot/flake.nix` with disko input for building netboot images
- **NEW**: MAC address-based automatic boot files (01-MAC-ADDRESS.ipxe) for N100 nodes
- **NEW**: Auto-chain script at `http://hal9000:8079/custom/autochain.ipxe` for netboot.xyz integration
- TFTP-based netboot with both hostname and MAC address detection in `modules/services/tftp-server.nix`
- HTTP serving of boot files via nginx on port 8079 for iPXE chainloading
- Build script in `scripts/build-netboot-images.sh` for creating and deploying netboot images
- Setup script in `scripts/setup-n100-macs.sh` for MAC address documentation
- **Fixed**: Netboot installer now has console access (serial and VGA) with auto-login
- **Fixed**: SSH host keys are pre-generated for consistent fingerprints
- **Fixed**: Build script updates TFTP iPXE scripts with correct init paths
- **Fixed**: `netboot-build` command runs non-interactively via `nix develop -c`
- **Fixed**: Optimized boot process - removed hardcoded non-existent interface names
- **Fixed**: Reduced network wait timeout from 120s to 30s for faster boot
- **Fixed**: Getty services explicitly enabled on tty1 and ttyS0 for reliable console access
- MAC addresses configured:
  - n100-01: `e0:51:d8:12:ba:97`
  - n100-02: `e0:51:d8:13:04:50`
  - n100-03: `e0:51:d8:13:4e:91`
  - n100-04: `e0:51:d8:15:46:4e`

### SSH Configuration Management (July 2025)
- Added automatic SSH configuration for local hosts and private IP ranges
- Created `users/regular/ssh/config.d/00-local-hosts` with StrictHostKeyChecking disabled
- Configured for all NixOS/Darwin hosts (both hostname and FQDN)
- Includes all private IP ranges (10.x, 192.168.x, 172.16-31.x)
- Special handling for hosts with specific usernames (cabby*, station*, server)
- Uses SSH Include directive to allow manual additions via config_external
- Applied to both Linux and Darwin hosts via jamesbrink-shared.nix

### Home-Manager Unfree Package Fix (July 2025)
- Fixed nixos-anywhere deployment failures due to unfree packages
- Added `nixpkgs.config.allowUnfree = true` to home-manager user configuration
- Ensures Discord and other unfree packages can be installed during deployment
- deploy-n100 command includes --impure flag for environment variable access

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

#### Quick Method (using built-in commands):
1. Run `secrets-add-host <hostname>` to get the host's SSH key
2. Add the key to `secrets/secrets.nix` in the host keys section
3. Add the host to all relevant `publicKeys` arrays
4. Run `secrets-rekey` to re-encrypt all secrets
5. Commit and push changes in the secrets submodule

#### Manual Method (for advanced cases):
1. Clone the secrets repository if working outside the submodule:
   ```bash
   git clone git@github.com:jamesbrink/nix-secrets.git ../nix-secrets
   ```

2. Get the new host's SSH public key:
   ```bash
   ssh-keyscan -t ed25519 <hostname>
   ```

3. Add the host key to `secrets.nix`:
   ```nix
   hostname = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
   ```

4. Add the new host to all `publicKeys` arrays in `secrets.nix`

5. Re-encrypt all secrets with the new recipient:
   ```bash
   # If using the built-in command:
   secrets-rekey
   
   # Or manually with agenix:
   RULES=../nix-secrets/secrets.nix agenix -r -i ~/.ssh/id_ed25519
   ```

6. Commit and push changes:
   ```bash
   git -C ../nix-secrets add -A
   git -C ../nix-secrets commit -m "Add <hostname> to age recipients"
   git -C ../nix-secrets push
   ```

7. Update the secrets input in the main repo:
   ```bash
   nix flake lock --update-input secrets
   ```

### Editing Existing Secrets
- To edit a secret: `secrets-edit <path>` or manually: `agenix -e <secret-file>`
- To create a new secret: `secrets-edit <new-path>` or manually: `agenix -e <new-secret-file>`
- Always commit and push changes to the secrets repository

### Security Notes
- Never commit plaintext secrets to the repository
- The secrets submodule is private and should remain so (Repository: `git@github.com:jamesbrink/nix-secrets.git`)
- Syncthing passwords are now managed at the host level, not in user configs
- Webhook tokens and API keys should be moved to encrypted secrets
- Never add local-only files to the repo (CLAUDE.local.md, settings.local.json)

### Development Best Practices
- Always use `deploy-test` before `deploy` on production systems
- Keep sensitive information in encrypted secrets only