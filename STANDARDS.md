# Core Standards

## Nix & Infrastructure

- Prefer existing upstream modules/options before writing custom logic. When custom modules are required, keep inputs explicit, expose options via `mkOption`, and document defaults.
- Every `.nix` file is formatted by `nixfmt` (via treefmt). Use two-space indentation, sorted attribute sets, and avoid inline shell unless unavoidable.
- Host files should only stitch profiles and host-specific overrides; business logic belongs in modules or scripts.
- Rebuild safety: any change must succeed under `nix flake check`, `nix build .#<target>`, and (when relevant) `deploy-test`.

## Bash & Scripts

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use long-form flags, `trap` cleanup when touching temp files, and `shellcheck` new scripts.
- Prefer idempotent behavior; scripts that mutate local configs must log actions and accept `--dry-run` when feasible.

## Documentation

- Markdown follows `markdownlint` (soon wired into treefmt). Keep sections short, use sentence-case headings, and update `README.md`, `TODO.md`, or per-module docs alongside code.
- Core docs (`VISION.md`, `TECH_STACK.md`, `DESIGN.md`, `STANDARDS.md`) must stay in sync with major architectural changes.

## Python (`scripts/themectl/`)

- Package as a simple module with a `pyproject.toml`; expose a CLI entrypoint (`themectl`).
- Enforce Ruff for lint/format, Pyright for type checking (use type hints everywhere), and pytest for tests. Keep zero global state; use dependency-injected paths/configs.
- Commands must be deterministic, print structured logs, and never require network access unless explicitly stated.
- Provide lightweight fixtures/mocks so CI and agents can run tests without live GUI apps.
- Keep Python files focused: aim for <800 lines, and never exceed ~1,500 lines. When approaching that ceiling, split helpers into modules/packages so each file covers a single concern.

## Reviews & Commits

- Use Conventional Commits, scope paths when helpful (`docs(core): add standards reference`).
- Before pushing: run `format`, `nix flake check`, and any module-specific tests (e.g., `pytest scripts/themectl` once it exists). Document deviations in PR descriptions or TODO entries.
- Always stage relevant files (`git add ...`) before running `deploy`, `nixos-rebuild`, or `darwin-rebuild` so remote builds pull the intended config and avoid “missing file” failures.
