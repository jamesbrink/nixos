#!/usr/bin/env bash
# jq filters use $id as a jq variable, not a shell one.
# shellcheck disable=SC2016
set -euo pipefail

# Download, verify and pack the Strata models declared in services.strata.
#   strata-provision                       plan for every model (no changes)
#   strata-provision --provision [ID...]   prepare all or the named models
# Run as the strata user: sudo -u strata strata-provision --provision
# Shards with identical bytes in another model (ISTA's shared PLE shard) are
# hard-linked instead of downloaded. Never starts services or activates NixOS.
: "${STRATA_MANIFEST:?Use the Nix-packaged strata-provision command}"
m() { jq -r "$@" "$STRATA_MANIFEST"; }

mode=${1:---plan}
case "$mode" in
  --plan | --provision) shift || true ;;
  -h | --help)
    sed -n '4,9p' "$0"
    exit 0
    ;;
  *)
    echo "Usage: strata-provision [--plan|--provision] [MODEL...]" >&2
    exit 2
    ;;
esac
if [ "$#" -gt 0 ]; then ids=("$@"); else mapfile -t ids < <(m '.models | keys[]'); fi
state=$(m .stateDir)

# A verified file gets a <file>.sha256 marker so later runs skip re-hashing.
verified() { [ -f "$1" ] && [ "$(cat "$1.sha256" 2>/dev/null)" = "$2" ]; }
mark() { printf '%s' "$2" >"$1.sha256"; }

fetch() { # url target sha256 size
  local url=$1 target=$2 sha=$3 size=$4 candidate
  if verified "$target" "$sha"; then return; fi
  if ! [ -f "$target" ]; then
    # Reuse identical bytes from another model directory (same filesystem).
    while IFS= read -r candidate; do
      if [ "$(cat "$candidate.sha256" 2>/dev/null)" = "$sha" ] ||
        { [ ! -f "$candidate.sha256" ] && echo "$sha  $candidate" | sha256sum --check --status; }; then
        ln "$candidate" "$target" && echo "linked $(basename "$target") from $candidate"
        break
      fi
    done < <(find "$state" -name '*.gguf' -size "${size}c" ! -path "$target" 2>/dev/null)
  fi
  if ! [ -f "$target" ]; then
    curl --fail --show-error --location --retry 5 --continue-at - "$url" --output "$target.partial"
    mv "$target.partial" "$target"
  fi
  echo "$sha  $target" | sha256sum --check
  mark "$target" "$sha"
}

need=0
for id in "${ids[@]}"; do
  m -e --arg id "$id" '.models[$id]' >/dev/null || {
    echo "Unknown model $id; known: $(m '.models | keys | join(", ")')" >&2
    exit 2
  }
  dir=$(m --arg id "$id" '.models[$id].dataDir')
  while IFS=$'\t' read -r file size; do
    [ -f "$dir/$file" ] || need=$((need + size))
  done < <(m --arg id "$id" '.models[$id].shards[] | [.file, (.size | tostring)] | @tsv')
  echo "$id: $(m --arg id "$id" '.models[$id].shards | length') shards in $dir"
done
mmproj_file=$(m .mmproj.file)
[ -f "$mmproj_file" ] || need=$((need + $(m .mmproj.size)))
mtp=$(m .mtpDir)
echo "Missing downloads: $need bytes (before reuse of identical shards); shared MTP: $([ -s "$mtp/rt/draft_vocab.bin" ] && echo present || echo 'to build (~6 GB download)')."
if [ "$mode" = --plan ]; then
  echo "Plan only. Use --provision to download, verify and pack."
  exit 0
fi

available=$(df -PB1 "$state" | awk 'NR == 2 {print $4}')
if [ "$available" -lt $((need + 8 * 1073741824)) ]; then
  echo "Need $need bytes plus 8 GiB headroom in $state; found $available." >&2
  exit 1
fi

fetch "$(m .mmproj.url)" "$mmproj_file" "$(m .mmproj.sha256)" "$(m .mmproj.size)"
if ! [ -s "$mtp/rt/draft_vocab.bin" ]; then
  mkdir -p "$mtp"
  export STRATA_MTP_REVISION
  STRATA_MTP_REVISION=$(m .mtpRevision)
  strata-mtp_fetch fetch --out "$mtp"
  strata-mtp_fetch verify --out "$mtp"
  strata-mtp_pack --src "$mtp" --experts q2_0 --out "$mtp/mtp-q2_0.gguf"
  strata-mtp_rt --gguf "$mtp/mtp-q2_0.gguf" --out "$mtp/rt"
  cp "$(m .draftVocab)" "$mtp/rt/draft_vocab.bin"
fi

for id in "${ids[@]}"; do
  dir=$(m --arg id "$id" '.models[$id].dataDir')
  url=$(m --arg id "$id" '.models[$id].url')
  mkdir -p "$dir"
  while IFS=$'\t' read -r file sha size; do
    fetch "$url/$file" "$dir/$file" "$sha" "$size"
  done < <(m --arg id "$id" '.models[$id].shards[] | [.file, .sha256, (.size | tostring)] | @tsv')
  if ! [ -s "$dir/pack/native_experts.txt" ]; then
    mapfile -t pack_args < <(m --arg id "$id" '.models[$id].packArgs[]')
    first=$(m --arg id "$id" '.models[$id].shards[0].file')
    strata-iq_pack --gguf "$dir/$first" --out "$dir/pack" "${pack_args[@]}"
  fi
  echo "$id: ready"
done
echo "Prepared data only; no service startup or NixOS activation."
