# Repository Guidelines

## Project Structure & Module Organization

`flake.nix` drives everything by pinning nixpkgs, agenix, and Darwin to consistent revisions and exports host configs plus dev shells. Hosts live under `hosts/<hostname>/` (lowercase-hyphen) and compose shared bits from `modules/darwin`, `modules/services`, `modules/home-manager`, and `profiles/`. Package overrides stay in `pkgs/` and `overlays/`, user-specific tweaks in `users/`, helper scripts in `scripts/`, and encrypted material in `secrets/` with recipients recorded in `SECRETS.md`. Review `VISION.md`, `DESIGN.md`, `TECH_STACK.md`, and `STANDARDS.md` before touching fleet-wide components.

## Build, Test, and Development Commands

Run `nix develop` (or `direnv allow`) to enter the dev shell; it exports helper commands and `NIXPKGS_ALLOW_UNFREE=1`. Core helpers:

- `format` – treefmt via `nixfmt` and `prettier`.
- `nix flake check --impure` – baseline validation for every change.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or `.darwinConfigurations.<host>.system`) – host build.
- `deploy <host>`, `deploy-test <host>`, `deploy-local <host>` – production, rehearsal, or constrained rollouts.
  Pair risky rollouts with `scripts/health-check.sh`, `scripts/show-generations.sh`, and `scripts/rollback.sh`.

## Coding Style & Naming Conventions

treefmt enforces two-space indentation and sorted attribute sets in `*.nix`; structured data also runs through `prettier`. File, module, host, and profile names must be lowercase with hyphens (`hosts/halcyon`, `ghostty-terminfo.nix`). Bash helpers start with `#!/usr/bin/env bash`, set `-euo pipefail`, and must pass `shellcheck scripts/*.sh`. Favor declarative modules over ad-hoc shell; document any imperative helper in `flake.nix`.

## Testing Guidelines

Minimum gate is `nix flake check --impure` plus `deploy-test <host>` for each affected machine. After activation run `scripts/health-check.sh <host>` to confirm services and `scripts/show-generations.sh <host>` to ensure rollback points. Secrets-heavy work should also run `scripts/secrets-verify.sh` and `scripts/scan-gitleaks.sh` (or `scripts/scan-secrets.sh --all`). Name tests after the host or module they verify (e.g., `deploy-test halcyon`, `nix build .#profiles.workstation`).

## Commit & Pull Request Guidelines

Use Conventional Commits (`feat(hosts/halcyon): enable yabai toggle`). Before opening a PR, run `format`, `nix flake check --impure`, and `deploy-test` for each impacted host; report their results in the PR body along with affected hosts/profiles, screenshots or command snippets for UI changes, and references to TODOs/issues. Document new secrets or manual steps in `SECRETS.md` or `docs/`.

## Security & Secrets

Encrypt credentials with `scripts/secrets-edit.sh <path>` and rotate recipients via `scripts/secrets-rekey.sh`. Keep secrets confined to `secrets/`, never commit plaintext, and scan prior to pushing using `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh --all`. Set `NIXPKGS_ALLOW_UNFREE=1` (provided by the dev shell) so regulated packages resolve consistently.
