# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **IMPORTANT**: When updating this file, always copy the contents to `.windsurfrules`, `.cursorrules`, and `.goosehints` to keep all AI assistant configurations in sync.

## Commands

### Development Commands
- `format`: Format all files using treefmt (`nixfmt` for .nix, `prettier` for HTML/CSS/JS/JSON)
- `check`: Check Nix expressions for errors (runs `nix flake check --impure`)

### Deployment Commands
- `deploy <hostname>`: Deploy configuration to a host (automatically detects local vs remote)
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
The codebase follows a modular NixOS flake structure with clear separation of concerns:

1. **Flake Configuration** (`flake.nix`):
   - Defines all external inputs (nixpkgs stable/unstable, home-manager, agenix, vscode-server)
   - Configures development shell with all deployment and maintenance commands
   - Defines NixOS configurations for each host with appropriate modules and overlays

2. **Host Configurations** (`hosts/*/`):
   - Each host has its own directory with `default.nix` and `hardware-configuration.nix`
   - Hosts import shared profiles, modules, and user configurations
   - Special configurations: `hal9000` (main server with AI services), `n100-*` (cluster nodes), `alienware` (desktop)

3. **Profiles** (`profiles/*/`):
   - Reusable system profiles (desktop, server, keychron)
   - Desktop profile includes GNOME, development tools, and remote access
   - Profiles can have stable and unstable variants

4. **Modules** (`modules/*/`):
   - Custom services (ai-starter-kit for n8n/qdrant/postgres integration)
   - Shared package sets (default.nix, devops.nix)
   - Service configurations with proper NixOS module patterns

5. **User Management** (`users/*/`):
   - Per-user configurations with home-manager integration
   - Supports both stable and unstable package channels per user
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

## Workflow Recommendations
- Always use `deploy-test` over `build` when on macOS

## Secrets Management Process
- To update secrets for agenix:
  1. Ensure the secret is prepared in the private secrets repository
  2. Use `agenix -e <secret-file>` to edit encrypted secrets
  3. Rekey secrets if host SSH keys have changed using `agenix -r`
  4. Commit and push changes to the secrets repository
  5. Deploy the configuration to apply new secrets