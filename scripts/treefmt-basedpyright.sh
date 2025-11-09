#!/usr/bin/env bash
set -euo pipefail

# Run basedpyright once from the repository root so treefmt can type-check
# the themectl project without needing to cd manually.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -f scripts/themectl/pyproject.toml ]]; then
  echo "treefmt-basedpyright: skipping (scripts/themectl/pyproject.toml not found)" >&2
  exit 0
fi

basedpyright --project scripts/themectl/pyproject.toml
