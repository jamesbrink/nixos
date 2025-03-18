# CLAUDE.md - Guide for Agentic Coding Assistants

> **IMPORTANT**: When updating this file, always copy the contents to `.windsurfrules`, `.cursorrules`, and `.goosehints` to keep all AI assistant configurations in sync.

## Commands
- `format`: Format Nix files with treefmt (`nixfmt` for .nix, `prettier` for HTML/CSS/JS/JSON)
- `check`: Check Nix expressions for errors
- `build <hostname>`: Build configuration for a host without deploying
- `deploy <hostname>`: Deploy configuration to a host (local or remote)
- `deploy-test <hostname>`: Test deployment without making changes
- `update`: Update NixOS and flake inputs
- `show-hosts`: List all available hosts
- `gc <hostname>`: Run garbage collection on a host
- `show-generations <hostname>`: Show NixOS generations on a host
- `rollback <hostname>`: Roll back to the previous generation

## Code Style Guidelines
- Use `nixfmt-rfc-style` formatter for Nix files
- Prioritize host-specific configurations in `hosts/*/default.nix` 
- Follow NixOS module patterns for shared services and packages
- Use agenix for secrets management
- Include `--impure` flag with Nix commands 
- When working on host configurations, check the existing modules structure
- Maintain separation between stable (nixos-24.11) and unstable packages
- Use descriptive names for options and attributes
- Follow existing indentation style (2 spaces)