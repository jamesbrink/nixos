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
TEMP_EDITOR=""

cleanup() {
  [[ -n "$TEMP_SOURCE" && -f "$TEMP_SOURCE" ]] && rm -f "$TEMP_SOURCE"
  [[ -n "$TEMP_EDITOR" && -f "$TEMP_EDITOR" ]] && rm -f "$TEMP_EDITOR"
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

AGENIX_STDIN=""
if [ -r /dev/tty ]; then
  AGENIX_STDIN="/dev/tty"
fi

if [[ "$SOURCE_MODE" != "none" ]]; then
  TEMP_EDITOR="$(mktemp)"
  cat <<'EOF' > "$TEMP_EDITOR"
#!/usr/bin/env bash
set -euo pipefail
if [ -z "${SECRET_SOURCE_FILE:-}" ]; then
  echo "SECRET_SOURCE_FILE is not set" >&2
  exit 1
fi
cat "$SECRET_SOURCE_FILE" > "$1"
EOF
  chmod +x "$TEMP_EDITOR"
  echo "Populating secret from ${SOURCE_FILE:-stdin}..."
  if [ -n "$AGENIX_STDIN" ]; then
    SECRET_SOURCE_FILE="$SOURCE_FILE" RULES=./secrets.nix EDITOR="$TEMP_EDITOR" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE" < "$AGENIX_STDIN"
  else
    SECRET_SOURCE_FILE="$SOURCE_FILE" RULES=./secrets.nix EDITOR="$TEMP_EDITOR" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE"
  fi
else
  if [ -n "$AGENIX_STDIN" ]; then
    RULES=./secrets.nix EDITOR="${EDITOR:-vim}" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE" < "$AGENIX_STDIN"
  else
    RULES=./secrets.nix EDITOR="${EDITOR:-vim}" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE"
  fi
fi
cd ..

echo ""
echo "✓ Secret updated: $SECRET_FILE"
