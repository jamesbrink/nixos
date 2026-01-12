# Repository Guidelines

## Project Structure & Module Organization

`flake.nix` pins nixpkgs, agenix, and Darwin revisions, exports dev shells, and composes hosts under `hosts/<hostname>/`. Shared logic lives in `modules/darwin`, `modules/services`, `modules/home-manager`, and `profiles/`. Place package overrides in `pkgs/` and `overlays/`, user tweaks in `users/`, helper scripts in `scripts/`, and encrypted credentials in `secrets/` with recipients tracked in `SECRETS.md`. Review `VISION.md`, `DESIGN.md`, `TECH_STACK.md`, and `STANDARDS.md` before editing fleet-wide modules.

## Build, Test, and Development Commands

- `nix develop` (or `direnv allow`) enters the dev shell with shared helpers and `NIXPKGS_ALLOW_UNFREE=1`.
- `format` runs treefmt (`nixfmt` + `prettier`) to enforce repository formatting.
- `nix flake check --impure` provides the baseline validation for all changes.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` (or `.darwinConfigurations.<host>.system`) builds a specific host profile.
- `deploy <host>`, `deploy-test <host>`, and `deploy-local <host>` perform production, rehearsal, or constrained rollouts; follow deployments with `scripts/health-check.sh <host>` and `scripts/show-generations.sh <host>`.

## Coding Style & Naming Conventions

treefmt enforces two-space indentation and sorted attribute sets in `*.nix`, while structured data runs through `prettier`. All files, modules, hosts, and profiles use lowercase hyphenated names (e.g., `hosts/halcyon`, `ghostty-terminfo.nix`). Bash helpers start with `#!/usr/bin/env bash`, set `-euo pipefail`, avoid ad-hoc shells when a declarative module suffices, and must pass `shellcheck scripts/*.sh`.

## Testing Guidelines

Minimum verification is `nix flake check --impure` plus `deploy-test <host>` for each impacted machine. After activation, run `scripts/health-check.sh <host>` to confirm services and `scripts/show-generations.sh <host>` to confirm rollback points. Secrets-heavy changes require `scripts/secrets-verify.sh` and `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh --all`. Name tests after the host or module they verify (e.g., `deploy-test halcyon`).

## Commit & Pull Request Guidelines

Use Conventional Commits that scope paths (e.g., `feat(hosts/halcyon): enable yabai toggle`). Before opening a PR, run `format`, `nix flake check --impure`, and `deploy-test` for each affected host, then report results in the PR body alongside impacted hosts/profiles, linked issues, and screenshots or command snippets for UI changes. Document any new secrets or manual steps in `SECRETS.md` or `docs/`.

## Security & Configuration Tips

Encrypt sensitive data with `scripts/secrets-edit.sh <path>` and rotate recipients via `scripts/secrets-rekey.sh`. Keep secrets confined to `secrets/`, never commit plaintext, and scan before pushing using `scripts/scan-gitleaks.sh` or `scripts/scan-secrets.sh --all`. Pair risky rollouts with `scripts/health-check.sh`, `scripts/show-generations.sh`, and `scripts/rollback.sh` to validate and recover quickly.

## GitHub Actions Troubleshooting

If a workflow run stays `queued` after fixing runner labels, force-cancel it with:

```bash
gh api --method POST -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/<owner>/<repo>/actions/runs/<run_id>/force-cancel
```

Confirm with `gh run view <run_id> -R <owner>/<repo> --json status,conclusion`; delete with `gh api --method DELETE /repos/<owner>/<repo>/actions/runs/<run_id>` only if the force step fails. See `docs/github-actions.md` for full notes (applied to runs 19433417619 and 19432457397).

## Rancher Monitoring Deployment

- Run `./scripts/deploy-k8s.py rancher` to bootstrap or refresh Rancher + monitoring. The script copies `k8s/rancher/grafana-nginx.conf` into the `grafana-nginx-proxy-config` ConfigMap and restarts Grafana so the Rancher UI proxy keeps working.
- If you prefer the generic helper (`./scripts/deploy-k8s.py helm rancher-monitoring rancher-charts/rancher-monitoring -n cattle-monitoring-system -f k8s/rancher/monitoring-values.yaml`), the script now performs the same config sync automatically after Helm finishes.
- Always verify via Rancher → Cluster → Monitoring plus direct <https://grafana.home.urandom.io> to ensure both access paths load without 404s.

## PostgreSQL Replica on hal9000

The PostgreSQL 17 replica runs on hal9000 (port 5432) replicating from Quantierra production via WAL shipping from S3. Use the `pg-replica` skill for status checks and queries.

**Mode switching:** The systemd service always starts in standby mode. To switch to read/write:

```bash
# Stop service, remove standby.signal, start postgres manually
ssh hal9000 "sudo systemctl stop postgresql-replica"
ssh hal9000 "sudo rm -f /storage-fast/pg_base/standby.signal && sudo -u postgres /run/current-system/sw/bin/postgres -D /storage-fast/pg_base &"
```

To return to standby: `ssh hal9000 "sudo pkill -u postgres postgres && sudo systemctl start postgresql-replica"`

## Core Docs

Always refer to `README.md` for an overview, then consult:

- `VISION.md` captures fleet goals and guardrails.
- `TECH_STACK.md` lists the supported platforms, languages, and tooling.
- `DESIGN.md` explains repository layout and ownership boundaries.
- `STANDARDS.md` codifies testing, documentation, and language-specific requirements (including the Python `themectl` rules).
- `AGENTS.md` covers collaboration with AI agents (Claude, GitHub Copilot, etc.).
- `CLAUDE.md` documents Claude usage, experiment notes, and emerging patterns.
- `HOTKEYS.md` catalogs custom keybindings and their rationale.
- `TODO.md` tracks active tasks and backlog items.
