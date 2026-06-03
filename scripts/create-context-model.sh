#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create an Ollama model with a custom context window size.

Usage:
  create-context-model <source_model> <context_size_k>

Arguments:
  source_model     Existing Ollama model name, for example qwen2.5-coder:14b.
  context_size_k   Context window size in thousands of tokens, for example 8, 16, 32, 64.

Examples:
  create-context-model qwen2.5-coder:14b 32
  create-context-model llama3:8b 16
  create-context-model phi3:mini 8
EOF
}

list_models() {
  ollama list | awk 'NR > 1 { print "  " $1 }'
}

require_ollama() {
  if ! command -v ollama >/dev/null 2>&1; then
    echo "Error: ollama is not installed or is not in PATH." >&2
    exit 1
  fi
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

require_ollama

source_model="$1"
context_size_k="$2"

if ! ollama list | awk 'NR > 1 { print $1 }' | grep -Fxq "$source_model"; then
  echo "Error: source model '$source_model' was not found in Ollama." >&2
  echo "Available models:" >&2
  list_models >&2
  exit 1
fi

if ! [[ "$context_size_k" =~ ^[0-9]+$ ]] || (( context_size_k < 1 )); then
  echo "Error: context_size_k must be a positive integer." >&2
  echo "Example valid values: 8, 16, 32, 64" >&2
  exit 1
fi

context_tokens=$((context_size_k * 1024))

if [[ "$source_model" == *":"* ]]; then
  model_name="${source_model%%:*}"
  model_tag="${source_model#*:}"
  target_model="${model_name}-${context_size_k}k:${model_tag}"
else
  target_model="${source_model}-${context_size_k}k"
fi

echo "Creating model '$target_model' with ${context_size_k}k (${context_tokens}) context tokens..."

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/Modelfile" <<EOF
FROM $source_model

PARAMETER num_ctx $context_tokens
PARAMETER num_thread 8
PARAMETER num_gpu 50
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
EOF

ollama create "$target_model" -f "$temp_dir/Modelfile"

if ollama list | awk 'NR > 1 { print $1 }' | grep -Fxq "$target_model"; then
  echo "Success: model '$target_model' was created."
  echo "Run it with: ollama run $target_model"
else
  echo "Error: failed to create model '$target_model'." >&2
  exit 1
fi
