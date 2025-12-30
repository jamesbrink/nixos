#!/usr/bin/env bash
# Install git hooks from scripts/hooks/ to .git/hooks/
# This avoids hardcoded nix store paths that become stale after garbage collection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

if [[ ! -d "$HOOKS_SRC" ]]; then
    echo "No hooks directory found at $HOOKS_SRC"
    exit 0
fi

echo "Installing git hooks..."

for hook in "$HOOKS_SRC"/*; do
    if [[ -f "$hook" ]]; then
        hook_name=$(basename "$hook")
        dst="$HOOKS_DST/$hook_name"

        # Remove existing hook (file or symlink)
        if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
            rm "$dst"
        fi

        # Create symlink
        ln -s "$hook" "$dst"
        chmod +x "$hook"
        echo "  Installed: $hook_name"
    fi
done

echo "Git hooks installed successfully!"
