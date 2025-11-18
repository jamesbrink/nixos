# Core Design

## Repository Layout

- `flake.nix` / `flake.lock`: inputs, overlays, packages, profiles, and host outputs.
- `hosts/<name>/`: entrypoints per machine (macOS + NixOS). Each imports shared profiles and module selections only—no inline logic.
- `profiles/`: reusable bundles (desktop, server, darwin, homelab). Profiles aggregate modules to express roles.
- `modules/`: leaf functionality. Notable subtrees:
  - `modules/home-manager/`: user programs, shells, theming.
  - `modules/darwin/`: Yabai, SKHD, fuzz-launchers, system services.
  - `modules/services/`: daemons (AI stack, Postgres/PostGIS, restic, netboot server, Windows VM helpers).
  - `modules/netboot/`, `modules/n100-disko.nix`, `modules/n100-network.nix`: host disk/network automation and PXE installers.
- `users/`: user-specific Home Manager overlays.
- `pkgs/` + `overlays/`: custom derivations and modifications to upstream packages.
- `scripts/`: operational helpers (deploy, secrets, diagnostics). `scripts/themectl/` hosts the cross-platform theme CLI.
- `external/omarchy/`: upstream theme assets managed as a submodule.

## State & Secrets

- Secrets live under `secrets/` as `.age` files; `SECRETS.md` tracks recipients.
- Mutable runtime state (e.g., `~/.config/alacritty/alacritty.toml`) is either generated via activation hooks or managed through helper scripts like `themectl`.

## Workflow

- Agents edit modules/profiles, run `format` (treefmt), `nix flake check`, and host-specific builds.
- Deployments flow through `scripts/deploy*` to keep remote hosts in sync.
- TODO-driven planning (`TODO.md`) documents active tasks, with these core docs serving as orientation for humans and automation.
