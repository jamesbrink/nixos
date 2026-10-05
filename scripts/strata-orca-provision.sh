#!/usr/bin/env bash
set -euo pipefail

# Default is a plan only. This command never starts services or activates NixOS.
DATA_DIR=${STRATA_ORCA_DATA_DIR:-/storage-fast/llm/strata-orca}
REVISION=e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc
BASE=https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF/resolve/$REVISION
SHARD1=Qwen3.8-Flash-Next-Uncensored-IQ3_XXS-00001-of-00002.gguf
SHARD2=Qwen3.8-Flash-Next-Uncensored-IQ3_XXS-00002-of-00002.gguf
HASH1=aaf57046943c6638480e8984835ce5ec29c486180ff71169d3c22c6929851b7b
HASH2=a19cf9bbe87bce45f312ef11401c88b675f3784c927d02fa2272822229e6a224
MTP_REVISION=de4b8e4d43b917e7706784d8bb445c9af86a3540

case "${1:---dry-run}" in
  --dry-run)
    echo "Plan: download 85,202,668,032 bytes of IQ3_XXS shards at $REVISION into $DATA_DIR/models."
    echo "Verify SHA256, prepare this model's compatibility pack/tokenizer and original-model MTP."
    echo "Budget at least 110 GB disk for weights, converted projections, MTP and temporary files."
    echo "No downloads, system changes, services, or activation in this plan. Use --provision to prepare files."
    exit 0
    ;;
  --provision) ;;
  *) echo "Usage: strata-orca-provision [--dry-run|--provision]" >&2; exit 2 ;;
esac

: "${STRATA_SHARE:?Use the Nix-packaged strata-orca-provision command}"
mkdir -p "$DATA_DIR/models" "$DATA_DIR/mtp"
cd "$DATA_DIR"
# Require the immutable draft revision to exist before mtp_fetch's fallback logic.
curl --fail --silent --show-error --location \
  "https://huggingface.co/Qwen/Qwen3.8-Flash-Next/resolve/$MTP_REVISION/model.safetensors.index.json" \
  --output mtp/pinned-index.json

fetch_shard() {
  local name=$1 hash=$2
  if ! [ -f "models/$name" ]; then
    curl --fail --show-error --location --retry 3 --continue-at - \
      "$BASE/$name" --output "models/$name.partial"
    echo "$hash  models/$name.partial" | sha256sum --check --status
    mv "models/$name.partial" "models/$name"
  fi
  echo "$hash  models/$name" | sha256sum --check
}
fetch_shard "$SHARD1" "$HASH1"
fetch_shard "$SHARD2" "$HASH2"

if ! [ -s pack/native_experts.txt ]; then
  strata-iq_pack --gguf "$DATA_DIR/models/$SHARD1" --out "$DATA_DIR/pack" --compat-bf16
fi
export STRATA_MTP_REVISION=$MTP_REVISION
strata-mtp_fetch fetch --out "$DATA_DIR/mtp"
strata-mtp_fetch verify --out "$DATA_DIR/mtp"
strata-mtp_pack --src "$DATA_DIR/mtp" --experts q2_0 --out "$DATA_DIR/mtp/mtp-q2_0.gguf"
strata-mtp_rt --gguf "$DATA_DIR/mtp/mtp-q2_0.gguf" --out "$DATA_DIR/mtp/rt"
cp "$STRATA_SHARE/data/draft_vocab.bin" "$DATA_DIR/mtp/rt/draft_vocab.bin"
echo "Prepared data only. No inference, service startup, or NixOS activation occurred."
