# Core Tech Stack

## Operating Systems & Provisioning

- **Nix flakes**: single source for hosts, dev shells, packages, and overlays.
- **NixOS** (laptops, servers) and **nix-darwin** (macOS) with **Home Manager** for user layers.
- **deploy-rs** scripts (`deploy`, `deploy-test`, `deploy-all`) for remote builds and rollbacks.

## Languages & Tooling

- **Nix** (nixfmt via treefmt) for system config.
- **Bash** for small helpers; guarded with `set -euo pipefail` + `shellcheck`.
- **Python** (`scripts/themectl/`) using Ruff, Pyright, pytest.
- **Lua** for Hammerspoon/Neovim glue.

## Desktop & UX Stack

- **Hyprland** (Wayland) + **Yabai/Hammerspoon** (macOS) for tiling parity.
- **Alacritty**, **Ghostty**, **Neovim**, **VSCode/Cursor** as primary dev tools.
- **Sketchybar**, **Karabiner**, **AltTab**, **Walker/fzf launcher** for ergonomics.

## Network Infrastructure

- **MikroTik CRS310-8G+2S+** router managed via Terraform (`mikrotik-terraform/` submodule).
- **Terraform** with `terraform-routeros` provider for DHCP, DNS, WireGuard VPNs, PXE boot.
- Network: `10.70.100.0/24` with domain `home.urandom.io`.

## Supporting Services

- **Agenix** for secrets, `restic` for backups, `tailscale`, `docker`, `podman`, and language runtimes (Go, Rust, Node, Python) provided via dev shells.
- **treefmt** orchestrates `nixfmt`, `prettier`, future Ruff/Markdownlint integration.

Everything should be available inside `nix develop` so agents can lint, build, test, and package without touching the global system.
