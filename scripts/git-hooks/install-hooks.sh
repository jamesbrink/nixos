#!/usr/bin/env bash
set -euo pipefail

# Install git hooks from scripts/git-hooks/ to .git/hooks/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

mkdir -p "$HOOKS_DIR"

# Install pre-push hook
cp "$SCRIPT_DIR/pre-push" "$HOOKS_DIR/pre-push"
chmod +x "$HOOKS_DIR/pre-push"
echo "  Installed: pre-push"

# Set recurse-submodules config
git -C "$REPO_ROOT" config push.recurseSubmodules on-demand
echo "  Configured: push.recurseSubmodules = on-demand"

echo "Done. Git hooks installed."
