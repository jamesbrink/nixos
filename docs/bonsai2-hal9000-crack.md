# Bonsai 2 CRACK on HAL9000

`bonsai-2-27b-crack` is an additional experimental model at
`http://hal9000:8080/v1`. The original `bonsai-2-27b` and its MTP bundle remain
unchanged. Both use the PrismML CUDA runtime, full GPU offload, the original Q8_0
vision projector, a 327,680-token shared Q4_0 KV pool, eight slots, a 32,768-token
output allowance, the same sampling settings, and a 1,800-second idle timeout.
CRACK has no published MTP head, so its entry omits speculative decoding.
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
