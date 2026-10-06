#!/usr/bin/env bash
set -euo pipefail

# Exact publisher Q4_K_M; keep IQ3_XXS and its MTP runtime in place.
DATA_DIR=${STRATA_ORCA_Q4_DATA_DIR:-/var/lib/strata-orca-q4_k_m}
REVISION=e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc
BASE=https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF/resolve/$REVISION
names=(
  Qwen3.8-Flash-Next-Uncensored-Q4_K_M-00001-of-00003.gguf
  Qwen3.8-Flash-Next-Uncensored-Q4_K_M-00002-of-00003.gguf
  Qwen3.8-Flash-Next-Uncensored-Q4_K_M-00003-of-00003.gguf
)
hashes=(
  fa6b8ea03042a47575c039b84af57e0169e0f1ceab539ab9edba08937bb237ef
  6fb88b39f4b6e15d8acac6172faf65fcc2503703375440eb71d557161ed20df8
  f2fc849eb4c14ac58253cc326f057b2f606f394004c1172e6c61c56dd0b0a075
)
case "${1:---dry-run}" in
  --dry-run)
    echo "Plan: verify/download 119,150,722,944 bytes of pinned Q4_K_M into $DATA_DIR/models."
    echo "Create this quantization's own compatibility pack and tokenizer."
    echo "The NixOS Q4 selection shares the existing verified IQ3 original-model MTP runtime."
    echo "No services, activation or downloads in this plan. Use --provision to prepare files."
    exit 0
    ;;
  --provision) ;;
  *) echo "Usage: strata-orca-q4-provision [--dry-run|--provision]" >&2; exit 2 ;;
esac

curl_auth=()
auth_header=""
if [ -n "${STRATA_HF_TOKEN_FILE:-}" ]; then
  auth_header=$(mktemp)
  chmod 0600 "$auth_header"
  trap 'rm -- "$auth_header"' EXIT
  printf 'Authorization: Bearer %s\n' "$(cat "$STRATA_HF_TOKEN_FILE")" > "$auth_header"
  curl_auth=(--header "@$auth_header")
fi
mkdir -p "$DATA_DIR/models"
for i in "${!names[@]}"; do
  target="$DATA_DIR/models/${names[$i]}"
  if ! [ -f "$target" ]; then
    curl "${curl_auth[@]}" --fail --show-error --location --retry 5 --continue-at - \
      "$BASE/${names[$i]}" --output "$target.partial"
    printf '%s  %s\n' "${hashes[$i]}" "$target.partial" | sha256sum --check --status
    mv "$target.partial" "$target"
  fi
  printf '%s  %s\n' "${hashes[$i]}" "$target" | sha256sum --check
 done
if ! [ -s "$DATA_DIR/pack/native_experts.txt" ]; then
  strata-iq_pack --gguf "$DATA_DIR/models/${names[0]}" --out "$DATA_DIR/pack" --compat-bf16
fi
printf 'Prepared Q4 data only; no deployment or service startup performed.\n'
