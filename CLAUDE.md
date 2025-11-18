# Repository Guidelines

## Project Structure & Module Organization

`flake.nix` pins nixpkgs (stable+unstable), agenix, and Darwin, producing dev shells plus `nixosConfigurations`/`darwinConfigurations`. Hosts live in `hosts/<hostname>/` (lowercase-hyphen) and compose modules from `modules/darwin`, `modules/services`, and `modules/home-manager`. Role bundles stay in `profiles/`, user overlays in `users/`, and derivations/overlays in `pkgs/` + `overlays/`. Utility scripts live in `scripts/`; secrets stay in `secrets/` with recipients tracked in `SECRETS.md`.

## Build, Test, and Development Commands

Run `nix develop` (or `direnv allow`) to unlock helper commands such as `format` and `deploy*`. Run `format` before commits; treefmt runs `nixfmt` on `*.nix` and `prettier` on structured data. Guard edits with `nix flake check --impure`; build via `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or `.darwinConfigurations.<host>.system`). Use `deploy <host>` for production, `deploy-test <host>` for rehearsals, `deploy-local <host>` for low-RAM boxes, `deploy-all` for the fleet, and pair risky rollouts with `scripts/health-check.sh`, `scripts/show-generations.sh`, and `scripts/rollback.sh`.

## Coding Style & Naming Conventions

treefmt enforces two-space indentation and attribute ordering. Keep file, module, and host names lowercase with hyphens (`ghostty-terminfo.nix`, `hosts/halcyon`). Bash utilities must start with `#!/usr/bin/env bash`, set `-euo pipefail`, and satisfy `shellcheck scripts/*.sh`. Favor declarative Nix modules over ad-hoc shell whenever possible; if imperative steps are unavoidable, place them in `scripts/` and document the helper in `flake.nix`.

## Testing Guidelines

Minimum bar for any change is `nix flake check --impure` plus `deploy-test <host>` for each affected machine. After activation, run `scripts/health-check.sh <host>` to confirm services and `scripts/show-generations.sh <host>` to ensure safe rollback points. Secrets-heavy work should also run `scripts/secrets-verify.sh` and `scripts/scan-gitleaks.sh` (or `scripts/scan-secrets.sh --all`) before publishing.

## Commit & Pull Request Guidelines

Use Conventional Commit prefixes (`feat:`, `fix:`, `docs:`) and add scopes when relevant (e.g., `feat(hosts/halcyon): enable yabai toggle`). Pull requests must list affected hosts/profiles, note whether `format`, `nix flake check`, and `deploy-test` ran, and reference any TODO entry or tracking issue. Include screenshots or command snippets for UI-facing changes and describe new secrets or extra manual steps in `SECRETS.md` or `docs/`.

## Security & Secrets

Manage age secrets with `scripts/secrets-edit.sh <path>` and rotate recipients via `scripts/secrets-rekey.sh`. Keep `NIXPKGS_ALLOW_UNFREE=1` (set in the dev shell) so unfree packages resolve. Scan for leaks using `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh --all` before pushing, and never commit unencrypted credentials.

## GitHub Actions Troubleshooting

Force cancel stuck runs with the documented REST endpoint when `gh run cancel <id>` leaves them queued. Run:

```bash
gh api --method POST -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/<owner>/<repo>/actions/runs/<run_id>/force-cancel
```

Then verify with `gh run view <run_id> -R <owner>/<repo> --json status,conclusion`. If the run still refuses to exit, delete it via `gh api --method DELETE /repos/<owner>/<repo>/actions/runs/<run_id>`. See `docs/github-actions.md` for context (used to clear queued runs 19433417619 and 19432457397 after fixing runner labels).

## Core References

`VISION.md` captures fleet goals and guardrails. `TECH_STACK.md` lists the supported platforms, languages, and tooling. `DESIGN.md` explains repository layout and ownership boundaries. `STANDARDS.md` codifies testing, documentation, and language-specific requirements (including the Python `themectl` rules). Consult these before landing changes.
