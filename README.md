# Nix Configurations

[![Build Runner Image](https://github.com/jamesbrink/nixos/actions/workflows/build-runner-image.yaml/badge.svg)](https://github.com/jamesbrink/nixos/actions/workflows/build-runner-image.yaml)
[![Check Upstream Runner](https://github.com/jamesbrink/nixos/actions/workflows/check-upstream-runner.yaml/badge.svg)](https://github.com/jamesbrink/nixos/actions/workflows/check-upstream-runner.yaml)
[![License: MIT](https://img.shields.io/github/license/jamesbrink/nixos.svg)](LICENSE)

This public flake keeps every personal and lab host—NixOS and macOS—on the same declarative track. Hosts compose reusable profiles, profiles compose modules, and modules encapsulate services, dev tooling, and desktop ergonomics. Home Manager, nix-darwin, deploy-rs, and Agenix supply the reproducible base, while docs in this repo describe how humans and AI agents collaborate on it.

## Daily workflow

1. `direnv allow` or `nix develop` to enter the dev shell (sets `NIXPKGS_ALLOW_UNFREE=1` plus lint/test helpers).
2. Run `format` (treefmt) before committing.
3. Validate with `nix flake check --impure`.
4. Build the desired target: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or `.darwinConfigurations.<host>.system`.
5. Deploy via `deploy-test <host>` → `deploy <host>` (or `deploy-local <host>`); follow with `scripts/health-check.sh <host>` and `scripts/show-generations.sh <host>`.
6. Keep secrets encrypted with `scripts/secrets-edit.sh` + `secrets/`; track recipients in `SECRETS.md` and verify via `scripts/secrets-verify.sh`.
7. Document major changes in `TODO.md` or module docs, and log new manual steps/secrets when touching infrastructure.

## Repository layout

- `flake.nix`, `flake.lock` – inputs for nixpkgs (stable/unstable), nix-darwin, Home Manager, deploy-rs helpers, dev shells, overlays, and host outputs.
- `hosts/<hostname>/` – thin host definitions for both NixOS (e.g., `hal9000`, `n100-*`) and Darwin (e.g., `halcyon`, `sevastopol`) that stitch together profiles, services, disks, and secrets.
- `profiles/` – shareable building blocks (`desktop/`, `server/`, `darwin/`, `n100/`, `keychron/`) that capture roles instead of repeating options per host.
- `modules/` – cross-host logic:
  - `darwin/` for nix-darwin specifics (Dock, file sharing, package bundles).
  - `home-manager/` for CLI/editor/shell layers.
  - `services/` for infra components (netboot, Postgres/PostGIS, backups, AI stack, Windows VM helpers).
  - `netboot/`, `restic-*.nix`, `ghostty-terminfo.nix`, etc., for focused features.
- `pkgs/` and `overlays/` – custom package definitions (PixInsight, Ollama, netboot assets, helper tooling) pulled into the flake outputs.
- `users/` – user-specific Home Manager overrides and preferences.
- `scripts/` – deployment helpers (`deploy*`, `health-check.sh`, `rollback.sh`), Rancher/Kubernetes bootstrap (`deploy-rancher.sh`, `deploy-k8s.py`), restic tooling, GC, menubar toggles, hotkey automation, and full secrets lifecycle scripts (`secrets-edit.sh`, `secrets-rekey.sh`, scanners).
- `k8s/` and `containers/` – Rancher/monitoring Helm values, GitHub runner containers, and supporting manifests.
- `docs/` – scenario guides (`pixinsight-*.md`, `desktop-environment-switching.md`, `samba-setup.md`, `github-actions.md`, etc.).
- `config/` – YAML configs consumed by scripts (e.g., hotkeys, themectl automation); `lib/hotkeys.nix` exposes the same data inside Nix.
- `secrets/` – Agenix-encrypted material with recipients/instructions cataloged in `SECRETS.md`.
- Top-level references: `VISION.md`, `DESIGN.md`, `TECH_STACK.md`, `STANDARDS.md`, `AGENTS.md`, `CLAUDE.md`, `HOTKEYS.md`, and `TODO.md` capture architecture, collaboration norms, tech choices, style guides, and backlog items.

### Tree view

```text
.
├── flake.nix
├── flake.lock
├── hosts/
│   ├── hal9000/
│   ├── n100-01/
│   ├── halcyon/
│   └── ...
├── profiles/
│   ├── desktop/
│   ├── server/
│   ├── darwin/
│   └── ...
├── modules/
│   ├── darwin/
│   ├── home-manager/
│   ├── services/
│   ├── netboot/
│   └── ...
├── pkgs/
│   ├── pixinsight/
│   ├── llama-cpp/
│   └── ...
├── overlays/
│   ├── pixinsight.nix
│   └── ...
├── users/
│   ├── regular/
│   ├── root.nix
│   └── ...
├── scripts/
│   ├── deploy-*.sh
│   ├── secrets-*.sh
│   └── ...
├── docs/
│   ├── pixinsight.md
│   ├── github-actions.md
│   └── ...
├── k8s/
│   ├── rancher/
│   ├── quantierra-github-runners/
│   └── ...
├── containers/
│   └── github-runner-full/
├── config/
│   ├── hotkeys.yaml
│   └── themectl-automation.yaml
├── lib/
│   └── hotkeys.nix
├── secrets/
│   ├── README.md
│   └── ...
├── AGENTS.md
├── CLAUDE.md
├── DESIGN.md
├── STANDARDS.md
├── TECH_STACK.md
├── VISION.md
├── TODO.md
└── README.md
```

## Tooling, quality, and safety checks

- Dev shell packages include `nixfmt`, `treefmt`, `prettier`, `age`, `openssh`, Python 3.13 with pytest/typer/rich, Ruff, BasedPyright, markdownlint, and other helpers so agents can lint/test without global installs.
- Secrets hygiene: run `scripts/scan-gitleaks.sh`, `scripts/scan-secrets.sh --all`, or the pre-commit hooks before pushing; never store plaintext outside `secrets/`.
- System hygiene: `scripts/restic-*.sh` handle backups, `scripts/nix-gc.sh` cleans stores, and `scripts/show-generations.sh` plus `scripts/rollback.sh` make rollbacks explicit.
- Rancher monitoring rollouts use `scripts/deploy-rancher.sh` (or `scripts/deploy-k8s.py helm ...`), which copies `k8s/rancher/grafana-nginx.conf` into the Grafana proxy ConfigMap and restarts Grafana automatically—verify via Rancher UI and <https://grafana.home.urandom.io>.
- GitHub Actions troubleshooting steps live in `docs/github-actions.md`; force-cancel stuck runs before deleting them.

## Conventions

- Follow `STANDARDS.md` for Nix, Bash, and soon Python (`scripts/themectl/`).
- Use Conventional Commits scoped to touched paths (`feat(hosts/halcyon): enable yabai toggle`).
- Anytime a host or module changes, update related docs, secrets metadata, and TODOs so future rebuilds stay reproducible.

Questions or new ideas? Start by reading `VISION.md` for context, scan `TODO.md`, and add updates or scripts instead of ad-hoc manual tweaks. The entire fleet should rebuild from these files alone.

Licensed under the MIT License — see `LICENSE`.
