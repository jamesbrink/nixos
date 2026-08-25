#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'EOF'
Usage: secrets-edit [--from-file PATH | --stdin] <secret-name>

Examples:
  secrets-edit global/claude-desktop-config
  secrets-edit --from-file /tmp/config.yaml hal9000/kubeconfig
  cat token.txt | secrets-edit --stdin jamesbrink/pypi-key

Notes:
  - Do NOT include the 'secrets/' prefix or '.age' suffix.
  - Use --from-file/--stdin to populate a secret non-interactively.
EOF
}

SOURCE_MODE="none"
SOURCE_FILE=""
TEMP_SOURCE=""
CP_SHIM_DIR=""

cleanup() {
  [[ -n "$TEMP_SOURCE" && -f "$TEMP_SOURCE" ]] && rm -f "$TEMP_SOURCE"
  [[ -n "$CP_SHIM_DIR" && -d "$CP_SHIM_DIR" ]] && rm -rf "$CP_SHIM_DIR"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-file)
      SOURCE_MODE="file"
      SOURCE_FILE="$2"
      shift 2
      ;;
    --stdin)
      SOURCE_MODE="stdin"
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option $1"
      show_usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -eq 0 ]; then
  show_usage
  exit 1
fi

if [[ "$SOURCE_MODE" == "file" && -z "${SOURCE_FILE:-}" ]]; then
  echo "Error: --from-file requires a path argument"
  exit 1
fi

if [[ "$SOURCE_MODE" == "file" && ! -f "$SOURCE_FILE" ]]; then
  echo "Error: Source file not found: $SOURCE_FILE"
  exit 1
fi

if [[ "$SOURCE_MODE" == "stdin" ]]; then
  TEMP_SOURCE="$(mktemp)"
  cat > "$TEMP_SOURCE"
  SOURCE_FILE="$TEMP_SOURCE"
fi

SECRET_PATH="$1"

# Remove 'secrets/' prefix if present
SECRET_PATH="${SECRET_PATH#secrets/}"

# Remove '.age' suffix if present
SECRET_PATH="${SECRET_PATH%.age}"

# The actual file path
SECRET_FILE="$SECRET_PATH.age"

# Change to secrets directory for proper path resolution
cd secrets

if [ ! -f "$SECRET_FILE" ]; then
  echo "Creating new secret: $SECRET_FILE"
  mkdir -p "$(dirname "$SECRET_FILE")"

  # Check if secret entry exists in secrets.nix
  if ! grep -q "\"$SECRET_FILE\"" secrets.nix; then
    echo "Adding new secret entry to secrets.nix..."

    # Backup secrets.nix
    cp secrets.nix secrets.nix.backup

    # Find the last existing secret entry and add after it
    # Insert before the closing brace of the attribute set
    awk -v new_line="  \"$SECRET_FILE\".publicKeys = allKeys;" '
      /^}$/ { print new_line; print; next }
      { print }
    ' secrets.nix > secrets.nix.new && mv secrets.nix.new secrets.nix

    echo "✓ Added entry to secrets.nix"
  fi
fi

# Use proper agenix syntax - use ed25519 by default
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE=~/.ssh/id_ed25519
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE=~/.ssh/id_rsa
else
  echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
  exit 1
fi

# Only the interactive path needs a terminal: agenix hands stdin to $EDITOR,
# and vim cannot run without one. The --from-file/--stdin path uses a shim
# editor that reads no input, so forcing /dev/tty there only breaks it.
#
# "[ -r /dev/tty ]" is not a sufficient test: the device node exists inside
# CI runners, cron jobs and agent shells with no controlling terminal, where
# it passes the read test but fails to open ("Device not configured").
AGENIX_STDIN=""
if [[ "$SOURCE_MODE" == "none" ]] && : < /dev/tty 2>/dev/null; then
  AGENIX_STDIN="/dev/tty"
fi

if [[ "$SOURCE_MODE" != "none" ]]; then
  # agenix ignores $EDITOR when stdin is not a terminal, substituting
  # "cp -- /dev/stdin" (see its edit() function). Feeding the payload on stdin
  # is therefore the supported non-interactive path -- an editor shim is
  # silently discarded and the secret is written empty.
  # GNU coreutils' cp refuses to read /dev/stdin on macOS, failing with
  # "skipping file '/dev/stdin', as it was replaced while being copied" and
  # leaving an encrypted *empty* file behind. BSD /bin/cp handles it, so put a
  # shim ahead of the nix coreutils on PATH for this one call.
  if [[ "$(uname -s)" == "Darwin" ]] && [ -x /bin/cp ]; then
    CP_SHIM_DIR="$(mktemp -d)"
    printf '#!/bin/sh\nexec /bin/cp "$@"\n' > "$CP_SHIM_DIR/cp"
    chmod +x "$CP_SHIM_DIR/cp"
  fi

  echo "Populating secret from ${SOURCE_FILE:-stdin}..."
  PATH="${CP_SHIM_DIR:+$CP_SHIM_DIR:}$PATH" \
    RULES=./secrets.nix agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE" < "$SOURCE_FILE"

  # An empty result is otherwise indistinguishable from success until the
  # secret is consumed, so verify before claiming the write worked.
  if [ -z "$(RULES=./secrets.nix agenix -d "$SECRET_FILE" -i "$IDENTITY_FILE" 2>/dev/null)" ]; then
    echo "Error: $SECRET_FILE decrypts to an empty value; refusing to report success." >&2
    exit 1
  fi
else
  if [ -z "$AGENIX_STDIN" ]; then
    echo "Error: no controlling terminal for the editor." >&2
    echo "Use --from-file PATH or --stdin to set this secret non-interactively." >&2
    exit 1
  fi
  RULES=./secrets.nix EDITOR="${EDITOR:-vim}" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE" < "$AGENIX_STDIN"
fi
cd ..

echo ""
echo "✓ Secret updated: $SECRET_FILE"
