#!/usr/bin/env bash
set -euo pipefail

# ISTA-DASLab's Qwen3.8-Flash-Next GSQ-RCO Q2_0, pinned as upstream Strata
# v0.2.10 setup.py does (HF_REVISIONS, ISTA_FILES). Reuses the Orca MTP runtime.
DATA_DIR=${STRATA_QWEN_Q2_DATA_DIR:-/var/lib/strata-qwen-flash-q2_0}
REVISION=ed59f92082b1e93c0e96d60a8b11aab089b52f09
BASE=https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/resolve/$REVISION/Q2_0
names=(
  Qwen3.8-Flash-Next-GSQ-RCO-Q2_0-00001-of-00002.gguf
  Qwen3.8-Flash-Next-GSQ-RCO-Q2_0-00002-of-00002.gguf
)
hashes=(
  69820c02ec7d0b45ef2ebb19d6620299db749fe2aded7f39f93c6b88b199b720
  316b46f3a2dbd68c900f43136ab9449f9dcc3725dfd8c794847c204bc161e113
)
case "${1:---dry-run}" in
  --dry-run)
    echo "Plan: verify/download 66,423,878,624 bytes of pinned Q2_0 into $DATA_DIR/models."
    echo "Create its compatibility pack and tokenizer; share the Orca original-model MTP runtime."
    echo "No services, activation or downloads in this plan. Use --provision to prepare files."
    exit 0
    ;;
  --provision) ;;
  *)
    echo "Usage: strata-qwen-flash-q2-provision [--dry-run|--provision]" >&2
    exit 2
    ;;
esac

mkdir -p "$DATA_DIR/models"
# Shards plus 8 GiB for the pack, filesystem headroom and interrupted transfers.
required=75013813216
for name in "${names[@]}"; do
  file="$DATA_DIR/models/$name"
  if [ -f "$file" ]; then
    required=$((required - $(stat -c %s "$file")))
  elif [ -f "$file.partial" ]; then
    required=$((required - $(stat -c %s "$file.partial")))
  fi
done
available=$(df -PB1 "$DATA_DIR" | awk 'NR == 2 {print $4}')
if [ "$available" -lt "$required" ]; then
  echo "Q2_0 provisioning requires $required more free bytes; found $available." >&2
  exit 1
fi
for i in "${!names[@]}"; do
  target="$DATA_DIR/models/${names[$i]}"
  if ! [ -f "$target" ]; then
    curl --fail --show-error --location --retry 5 --continue-at - \
      "$BASE/${names[$i]}" --output "$target.partial"
    printf '%s  %s\n' "${hashes[$i]}" "$target.partial" | sha256sum --check --status
    mv "$target.partial" "$target"
  fi
  printf '%s  %s\n' "${hashes[$i]}" "$target" | sha256sum --check
done
if ! [ -s "$DATA_DIR/pack/native_experts.txt" ]; then
  strata-iq_pack --gguf "$DATA_DIR/models/${names[0]}" --out "$DATA_DIR/pack"
fi
printf 'Prepared Q2_0 data only; no deployment or service startup performed.\n'
