# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Deploy Commands

Enter the dev shell first: `nix develop` (or `direnv allow`) — sets `NIXPKGS_ALLOW_UNFREE=1` and exposes all helpers.

| Command                                                               | Purpose                                             |
| --------------------------------------------------------------------- | --------------------------------------------------- |
| `format`                                                              | Run treefmt (nixfmt + prettier)                     |
| `nix flake check --impure`                                            | Baseline validation for all changes                 |
| `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` | Build NixOS host                                    |
| `nix build .#darwinConfigurations.<host>.system`                      | Build Darwin host                                   |
| `deploy <host>`                                                       | Production deployment                               |
| `deploy-test <host>`                                                  | Dry-run deployment (no activation)                  |
| `deploy-local <host>`                                                 | Build locally, push to remote (for low-RAM targets) |
| `scripts/health-check.sh <host>`                                      | Post-deploy service verification                    |
| `scripts/show-generations.sh <host>`                                  | List rollback points                                |
| `scripts/rollback.sh <host>`                                          | Revert to previous generation                       |

**Secrets management:**

- `secrets-edit <path>` — edit/create encrypted secret (auto-adds to secrets.nix)
- `secrets-rekey` — re-encrypt all secrets with current recipients
- `secrets-verify` — check all secrets decrypt correctly
- `scan-gitleaks` or `scan-secrets --all` — scan for leaked credentials before push

**Kubernetes (Rancher + monitoring):**

- `./scripts/deploy-k8s.py rancher` — bootstrap/refresh Rancher + Grafana proxy

## Architecture Overview

### Flake Structure

`flake.nix` defines:

- **Inputs**: nixpkgs (stable 25.11), nixos-unstable, home-manager, nix-darwin, agenix, disko, plus external flakes (comfyui-nix, zerobyte, etc.)
- **Dev shells**: Cross-platform (x86_64-linux, aarch64-darwin, x86_64-darwin) with Python 3.13, Ruff, BasedPyright, treefmt, age, and deployment helpers
- **Host outputs**: `nixosConfigurations` (hal9000, alienware, n100-01 through n100-04) and `darwinConfigurations` (halcyon)
- **Packages**: `themectl` CLI for cross-platform theme management

### Module Hierarchy

```
hosts/<hostname>/default.nix   # Thin host definitions — imports only, no inline logic
    ↓ imports
profiles/{desktop,server,darwin,n100}/   # Role bundles (aggregate modules)
    ↓ imports
modules/
├── darwin/          # nix-darwin specifics (Dock, file sharing, yabai, skhd)
├── home-manager/    # User programs, shells, editors, theming
│   └── hyprland/themes/lib.nix  # Shared theme registry for Darwin + Hyprland
├── services/        # Daemons (AI stack, Postgres/PostGIS, restic, netboot)
└── netboot/         # PXE installer automation
```

### Key Patterns

**Host files** should only stitch profiles and host-specific overrides. Business logic belongs in modules or `scripts/`.

**Overlays** (`overlays/`) provide `unstablePkgs` and custom derivations (PixInsight, llama-cpp). Access via `pkgs.unstablePkgs.<package>`.

**Secrets** live in `secrets/` as `.age` files encrypted via agenix. Recipients are tracked in `secrets/secrets.nix`. Hosts decrypt using their SSH host key (`/etc/ssh/ssh_host_ed25519_key`).

**Theme system** (`scripts/themectl/`) is a Python CLI that:

- Reads theme metadata from `modules/home-manager/hyprland/themes/lib.nix`
- Syncs wallpapers from `external/omarchy/` submodule
- Rewrites configs for Alacritty, Ghostty, VSCode, Neovim, tmux
- Drives yabai BSP/native mode toggle on macOS

### PostgreSQL Replica (hal9000)

Port 5432, replicating from Quantierra production via S3 WAL shipping. Use the `pg-replica` skill for status/queries.

**Mode switching:**

```bash
# To read/write mode:
ssh hal9000 "sudo systemctl stop postgresql-replica"
ssh hal9000 "sudo rm -f /storage-fast/pg_base/standby.signal && sudo -u postgres /run/current-system/sw/bin/postgres -D /storage-fast/pg_base &"

# Back to standby:
ssh hal9000 "sudo pkill -u postgres postgres && sudo systemctl start postgresql-replica"
```

## Coding Standards

**Nix**: Two-space indentation, sorted attribute sets, formatted by nixfmt. Prefer upstream modules before writing custom logic.

**Bash**: `#!/usr/bin/env bash` with `set -euo pipefail`. Must pass `shellcheck scripts/*.sh`.

**Python** (`scripts/themectl/`): Type hints everywhere, Ruff for lint/format, BasedPyright for type checking, pytest for tests. Keep files under 800 lines.

**Naming**: Lowercase hyphenated names for files, modules, hosts, profiles (e.g., `hosts/halcyon`, `ghostty-terminfo.nix`).

**Commits**: Conventional Commits scoped to paths (e.g., `feat(hosts/halcyon): enable yabai toggle`).

## Pre-Push Checklist

1. `format` — run treefmt
2. `nix flake check --impure` — validate all hosts build
3. `deploy-test <host>` — for each affected host
4. `scan-gitleaks` or `scan-secrets --all` — no leaked credentials
5. Stage relevant files before `deploy` to avoid "missing file" failures on remote builds

## Reference Docs

- `VISION.md` — fleet goals and guardrails
- `DESIGN.md` — repository layout and ownership boundaries
- `TECH_STACK.md` — supported platforms, languages, tooling
- `STANDARDS.md` — testing, documentation, language-specific requirements
- `HOTKEYS.md` — keybinding reference (Yabai, Hyprland, tmux, Neovim)
- `TODO.md` — active tasks and backlog
- `SECRETS.md` — secrets lifecycle and Kubernetes integration
