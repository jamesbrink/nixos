# Repository Guidelines

## Project Structure & Module Organization

- `flake.nix` defines all flake inputs (stable + unstable nixpkgs, darwin, agenix, devshell) and outputs the dev shells, NixOS/Darwin configurations, and custom packages.
- Host entrypoints live under `hosts/<hostname>/`; keep host names lowercase with hyphens (e.g., `hosts/hal9000`) so they match the flake outputs.
- Shared building blocks sit in `modules/` (Darwin modules in `modules/darwin/`, services in `modules/services/`, Home Manager modules in `modules/home-manager/`). Role-based bundles live in `profiles/`, and `users/` contains per-user Home Manager overlays.
- Custom derivations belong in `pkgs/` with overlays in `overlays/`; multi-step workflows and maintenance utilities go into `scripts/`.
- Secrets are managed through the `secrets/` agenix submodule. Never commit raw credentials—use the `secrets-*.sh` helpers instead and document recipients in `SECRETS.md`.

## Build, Test, and Development Commands

- Enter the dev shell with `nix develop` (or `direnv allow`); it exposes helper commands such as `format`, `deploy`, and `health-check`.
- Run `format` before every commit to execute treefmt (`nixfmt` for `*.nix`, `prettier` for JSON/YAML/HTML).
- `nix flake check --impure` validates the evaluation graph; use it before rebasing large changes.
- Build without deploying via `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or `.darwinConfigurations.<host>.system`).
- Apply a configuration with `deploy <host>`, rehearse with `deploy-test <host>`, build locally for low-RAM targets via `deploy-local <host>`, and update every machine with `deploy-all`.
- Post-build maintenance scripts (`health-check.sh`, `show-generations.sh`, `rollback.sh`) live in `scripts/` and should accompany risky changes.

## Coding Style & Naming Conventions

- Let `treefmt` enforce style; `nixfmt` standardizes two-space indentation and attribute ordering, while `prettier` formats structured data files.
- Keep file and module names lower-case with hyphens (`ghostty-terminfo.nix`, `restic-backups.nix`) to mirror existing patterns.
- Bash scripts must start with `#!/usr/bin/env bash`, use `set -euo pipefail`, and pass `shellcheck` (`shellcheck scripts/*.sh`) when feasible.
- Prefer declarative options over ad-hoc shell commands; when imperative steps are unavoidable, place them in `scripts/` with clear `help` text in `flake.nix`.

## Testing Guidelines

- Minimum bar: `nix flake check --impure` plus `deploy-test <host>` for every touched machine to catch activation errors before they hit production.
- Use `scripts/health-check.sh <host>` after deploying to confirm services, and `scripts/show-generations.sh <host>` to ensure rollback points exist.
- For secrets-heavy edits, run `scripts/secrets-verify.sh` to confirm all recipients can decrypt; pair with `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh` before pushing.

## Commit & Pull Request Guidelines

- Follow the observed Conventional Commit style (`feat:`, `docs:`, `wip:`); include a scoped prefix when possible (`feat(hosts/halcyon): enable yabai toggle`).
- Each PR description should list affected hosts/profiles, note whether `format`, `nix flake check`, and `deploy-test` were run, and link any tracking issue or TODO entry.
- Provide screenshots or command snippets when UI-facing (e.g., Dock tweaks) and mention any new secrets or external steps in `SECRETS.md`/`docs/`.

## Security & Secrets

- Access encrypted material through `scripts/secrets-edit.sh <path>`; never edit `.age` files manually. Regenerate recipients with `scripts/secrets-rekey.sh` after key rotations.
- Keep `NIXPKGS_ALLOW_UNFREE=1` (already set in the dev shell) when running `nix` commands so unfree packages resolve consistently.
- Run `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh --all` before publishing branches to prevent accidental leakage.
