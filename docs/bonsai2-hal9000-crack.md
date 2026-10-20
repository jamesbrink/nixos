# Bonsai 2 CRACK on HAL9000

`bonsai-2-27b-crack` is an additional experimental model at
`http://hal9000:8080/v1`. The original `bonsai-2-27b` and its MTP bundle remain
unchanged. Both use the PrismML CUDA runtime, full GPU offload, the original Q8_0
vision projector, a 327,680-token shared Q4_0 KV pool, eight slots, a 32,768-token
output allowance, the same sampling settings, and a 1,800-second idle timeout.
It serves a locally grafted CRACK + MTP file with the same `draft-mtp`
(`--spec-draft-n-max 1`) speculation as the original; see [MTP graft](#mtp-graft).
Switching models unloads the previous model and drops its prompt caches.

## Model provenance and storage

- Publisher: [dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF](https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF)
- Revision: `3d36486a5fb2a3868116b8f6e768179e2391d28d`
- File: `Bonsai-2-27B-PQ2_0-CRACK.gguf` (7,206,168,928 bytes)
- SHA256: `5b24ea3eebc3e0bccd05fb474eb88b10c57699d71a5db2f29485e3789a70d55d`
- Directory: `/storage-fast/llm/models/Bonsai-2-27B-Ternary-CRACK`

The file lives on the same `storage-fast/llm` ZFS dataset as the existing Bonsai
weights. Like those weights, it is provisioned separately from the Nix closure.
The server uses `-lm none` to load directly rather than mmap the GGUF.

To provision on HAL9000, download to a temporary filename, verify, then rename:

```bash
set -euo pipefail
model_dir=/storage-fast/llm/models/Bonsai-2-27B-Ternary-CRACK
mkdir -p "$model_dir"
curl -fL --retry 3 --continue-at - \
  -o "$model_dir/Bonsai-2-27B-PQ2_0-CRACK.gguf.part" \
  https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF/resolve/3d36486a5fb2a3868116b8f6e768179e2391d28d/Bonsai-2-27B-PQ2_0-CRACK.gguf
echo "5b24ea3eebc3e0bccd05fb474eb88b10c57699d71a5db2f29485e3789a70d55d  $model_dir/Bonsai-2-27B-PQ2_0-CRACK.gguf.part" | sha256sum -c -
mv "$model_dir/Bonsai-2-27B-PQ2_0-CRACK.gguf.part" \
  "$model_dir/Bonsai-2-27B-PQ2_0-CRACK.gguf"
```

## MTP graft

dealignai publishes CRACK without a NextN/MTP layer. The original entry's
ProCreations bundle (`Ternary-Bonsai-2-27B-PQ2_0-MTP-Q8_0.gguf`) is PrismML's
official file byte for byte plus one `blk.64` MTP layer. CRACK is the same
official file with 34 of its 851 tensors abliterated; all metadata except
`general.name` matches, and every tensor keeps its type and shape. So
`scripts/bonsai-crack-mtp-graft.py` copies the bundle and overwrites those 34
tensors in place with CRACK's bytes, then verifies all 851 tensors against
CRACK and the 15 `blk.64` tensors against the bundle.

- Output: `Bonsai-2-27B-PQ2_0-CRACK-MTP-Q8_0.gguf`, 7,657,489,728 bytes,
  SHA256 `af4bc96d8471ebc4ff0dff6dbac4944b5e1ae4d751148beb4fb9441dceccad75`,
  beside the original CRACK file. Its `general.name` still reads the bundle's
  name (cosmetic; rewriting it would move every tensor offset).
- The head was trained on the original model's hidden states; drafts are
  verified by CRACK itself, so output is CRACK's, and only acceptance (speed)
  can differ.
- An alternative third-party bundle (ManniX-ITA, Qwen3.8-27B head) needs the
  opencoti engine and is not used.

Reproduce on HAL9000 (needs PrismML's gguf-py for PQ2_0; the pinned
`llama-cpp-prism` input revision's `gguf-py` directory):

```bash
PYTHONPATH=/path/to/prism/gguf-py python3 scripts/bonsai-crack-mtp-graft.py \
  /storage-fast/llm/models/Bonsai-2-27B-Ternary-CRACK/Bonsai-2-27B-PQ2_0-CRACK.gguf \
  /storage-fast/llm/models/Ternary-Bonsai-2-27B-MTP/Ternary-Bonsai-2-27B-PQ2_0-MTP-Q8_0.gguf \
  /storage-fast/llm/models/Bonsai-2-27B-Ternary-CRACK/Bonsai-2-27B-PQ2_0-CRACK-MTP-Q8_0.gguf
```

Python needs numpy, pyyaml, sentencepiece and tqdm.

## Local OMP

The local `~/.omp/agent/models.yml` adds an explicit `bonsai-2-27b-crack` model
and matching override under the existing `bonsai2-local` provider, retaining the
original model and default selections.
It copies Bonsai's reasoning mappings, text/image inputs, 262,144-token
per-conversation limit and 32,768-token output allowance. The server pool is
shared across slots; it does not grant 320K to each conversation.

Both the explicit model definition and its override set `imageInputDecoder: stb`.
PrismML's image decoder cannot load WebP; this tells OMP to convert WebP images
to PNG, including images already present in conversation history. Without this
setting, pasted images can produce HTTP 400 "Failed to load image or audio file"
before vision inference begins. Restart OMP after changing local model settings.

The local `~/.omp/agent/config.yml` includes a matching shortcut:

```yaml
modelRoles:
  crack: bonsai2-local/bonsai-2-27b-crack:medium
```

Start a new session with:

```bash
omp --model @crack
```

Publisher capability and refusal-removal claims are not local acceptance results.
User testing determines suitability for real work.

## Activation and verification

The model download passed SHA256 verification on 2026-10-18. Formatting, local
`nix flake check --impure`, the HAL9000 system build and `deploy-test hal9000`
passed. The generated llama-swap configuration differs only by the new CRACK
entry. OMP catalog validation lists the new selector with the intended settings.
Activation completed on 2026-10-18 as system generation 1363. The shared endpoint
was healthy and listed both Bonsai entries; CRACK was left unloaded. The existing
unrelated `mold-acl.service` failure caused activation to return a warning status.
After the OMP WebP conversion fix, the user confirmed vision was working.
No agent-initiated CRACK inference was performed, at the user's instruction.

Activating this system configuration restarts `llama-swap.service`, unloading
the running model. Coordinate activation with active users; a built or staged
configuration does not make the new route available in the existing process.
