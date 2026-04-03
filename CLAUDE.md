# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Deploy Commands

Enter the dev shell first: `nix develop` (or `direnv allow`) — sets `NIXPKGS_ALLOW_UNFREE=1` and exposes all helpers.

| Command                   | Purpose                                             |
| ------------------------- | --------------------------------------------------- |
| `format`                  | Run treefmt (nixfmt + prettier + ruff + shellcheck) |
| `check`                   | Run `nix flake check --impure`                      |
| `build <host>`            | Build host (auto-detects NixOS vs Darwin)           |
| `deploy <host>`           | Production deployment                               |
| `deploy-test <host>`      | Dry-run deployment (no activation)                  |
| `deploy-local <host>`     | Build locally, push to remote (for low-RAM targets) |
| `deploy-all`              | Parallel deploy to all hosts with summary report    |
| `health-check <host>`     | Post-deploy service verification                    |
| `show-generations <host>` | List rollback points                                |
| `rollback <host>`         | Revert to previous generation                       |
| `show-hosts`              | List all available host names                       |

All devshell commands (including the ones below) require `--impure` under the hood since `NIXPKGS_ALLOW_UNFREE=1` is set. When running raw `nix build` or `nix flake check` outside the devshell, pass `--impure`.

**Secrets management:**

- `secrets-edit <path>` — edit/create encrypted secret (auto-adds to secrets.nix)
- `secrets-rekey` — re-encrypt all secrets with current recipients
- `secrets-verify` — check all secrets decrypt correctly
- `scan-gitleaks` or `scan-secrets --all` — scan for leaked credentials before push

**Kubernetes (Rancher + monitoring):**

- `deploy-k8s rancher` — bootstrap/refresh Rancher + Grafana proxy

## Architecture Overview

### Flake Structure

`flake.nix` defines:

- **Inputs**: nixpkgs (stable 25.11), nixos-unstable, home-manager, nix-darwin, agenix, disko, plus external flakes (comfyui-nix, invokeai, ai-toolkit, zerobyte, mold, etc.)
- **Dev shells**: Cross-platform (x86_64-linux, aarch64-darwin, x86_64-darwin) with Python 3.13, Ruff, BasedPyright, treefmt, age, and deployment helpers
- **Host outputs**: `nixosConfigurations` (hal9000, alienware, n100-01 through n100-04) and `darwinConfigurations` (halcyon, bender)
- **Packages**: `themectl` CLI for cross-platform theme management

### External Flake Wiring Pattern

When adding an external flake to a host, three things must be wired in `flake.nix`:

1. Add the flake input (e.g., `invokeai.url = "github:jamesbrink/InvokeAI/feature/nix-flake"`)
2. Add `<flake>.nixosModules.default` (or `darwinModules.default`) to the host's `modules` list
3. Add `<flake>.overlays.default` to the host's `nixpkgs.overlays` list

Then configure the service in the host's `default.nix`. See hal9000 (comfyui, invokeai, ai-toolkit, zerobyte, mold) and bender (invokeai, ai-toolkit) as reference.

### Module Hierarchy

```
hosts/<hostname>/default.nix   # Thin host definitions — imports only, no inline logic
    ↓ imports
profiles/{desktop,server,darwin,n100}/   # Role bundles (aggregate modules)
    ↓ imports
modules/
├── darwin/          # nix-darwin specifics (Dock, file sharing, yabai, skhd)
├── home-manager/    # User programs, shells, editors, theming
├── themes/          # Shared theme registry for Darwin + Hyprland
│   ├── lib.nix      # Theme metadata, wallpaper refs, JSON export
│   ├── colors/      # Per-theme TOML color definitions
│   └── definitions/ # Per-theme Nix attribute sets
├── services/        # Daemons (AI stack, Postgres/PostGIS, restic, netboot)
└── netboot/         # PXE installer automation
```

### Key Patterns

**Host files** should only stitch profiles and host-specific overrides. Business logic belongs in modules or `scripts/`.

**Profiles** aggregate modules into roles: `server` (NixOS servers), `desktop` (NixOS with GUI), `darwin` (full macOS workstation), `darwin-slim` (headless macOS), `n100` (mini-PC cluster nodes), `keychron` (keyboard config). Darwin hosts use `home-manager-unstable` (follows `nixos-unstable`); NixOS hosts use stable `home-manager` (follows `nixpkgs`).

**specialArgs** passed to every host include `inputs`, `agenix`, `secretsPath`, and `hotkeysBundle`. Some hosts also get `self`, `claude-desktop`, `unstablePkgs`, and external flake inputs (e.g., `comfyui-nix`, `acris-scrapers`). These are defined per-host in `flake.nix` and available in any imported module.

**Overlays** (`overlays/`) provide `unstablePkgs` and custom derivations (PixInsight, gogcli). Access via `pkgs.unstablePkgs.<package>`.

**Secrets** live in `secrets/` as `.age` files encrypted via agenix. Recipients are tracked in `secrets/secrets.nix`. Hosts decrypt using their SSH host key (`/etc/ssh/ssh_host_ed25519_key`).

**Network Infrastructure** is managed via the `mikrotik-terraform/` submodule (private repo with secrets). It configures the MikroTik CRS310-8G+2S+ router:

- Network: `10.70.100.0/24` with domain `home.urandom.io`
- DHCP static leases, DNS records, WireGuard VPNs, PXE boot
- Commands: `cd mikrotik-terraform && nix develop`, then `tf-plan` / `tf-apply`
- See `mikrotik-terraform/README.md` for full documentation

**Theme system** (`scripts/themectl/`) is a Python CLI that:

- Reads theme metadata from `modules/themes/lib.nix` and color definitions in `modules/themes/colors/`
- Syncs wallpapers from `external/omarchy/` submodule
- Rewrites configs for Alacritty, Ghostty, VSCode, Neovim, tmux, btop
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

**Nix**: Two-space indentation, sorted attribute sets, formatted by `nixfmt`. Prefer upstream modules before writing custom logic.

**Bash**: `#!/usr/bin/env bash` with `set -euo pipefail`. Checked by `shellcheck` (with `-x -e SC1091,SC2029`).

**Python** (`scripts/themectl/`): Type hints everywhere, Ruff for lint/format, BasedPyright for type checking, pytest for tests. Keep files under 800 lines.

**treefmt** (`treefmt.toml`) runs: `nixfmt` (_.nix), `prettier` (HTML/CSS/JS/JSON/YAML), `markdownlint --fix` (_.md), `ruff format` + `ruff check --fix` (_.py), `shellcheck` (_.sh), `basedpyright` (themectl only).

**Naming**: Lowercase hyphenated names for files, modules, hosts, profiles (e.g., `hosts/halcyon`, `ghostty-terminfo.nix`).

**Commits**: Conventional Commits scoped to paths (e.g., `feat(hosts/halcyon): enable yabai toggle`).

## Pre-Push Checklist

1. `format` — run treefmt
2. `nix flake check --impure` — validate all hosts build
3. `deploy-test <host>` — for each affected host
4. `scan-gitleaks` or `scan-secrets --all` — no leaked credentials
5. Stage relevant files before `deploy` to avoid "missing file" failures on remote builds

## Submodules

| Path                  | Purpose                                    | Contains Secrets      |
| --------------------- | ------------------------------------------ | --------------------- |
| `secrets/`            | Agenix-encrypted secrets (.age files)      | Yes                   |
| `mikrotik-terraform/` | MikroTik router IaC (DHCP, DNS, VPN, PXE)  | Yes (tfvars, tfstate) |
| `external/omarchy/`   | Upstream theme assets (wallpapers, colors) | No                    |

**Keeping submodules in sync:** Private submodules (`secrets/`, `mikrotik-terraform/`) must be pushed before the main repo. This is enforced by:

1. Git config `push.recurseSubmodules = on-demand` — auto-pushes submodules
2. Pre-push hook — blocks push if submodules have unpushed commits

To install hooks after cloning: `./scripts/git-hooks/install-hooks.sh`

## GitHub Actions

If a workflow run stays `queued` after fixing runner labels, force-cancel it:

```bash
gh api --method POST -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/<owner>/<repo>/actions/runs/<run_id>/force-cancel
```

Confirm with `gh run view <run_id> -R <owner>/<repo> --json status,conclusion`. See `docs/github-actions.md` for full notes.

## Reference Docs

- `VISION.md` — fleet goals and guardrails
- `DESIGN.md` — repository layout and ownership boundaries
- `TECH_STACK.md` — supported platforms, languages, tooling
- `STANDARDS.md` — testing, documentation, language-specific requirements
- `HOTKEYS.md` — keybinding reference (Yabai, Hyprland, tmux, Neovim)
- `TODO.md` — active tasks and backlog
- `SECRETS.md` — secrets lifecycle and Kubernetes integration
- `mikrotik-terraform/README.md` — network infrastructure management
