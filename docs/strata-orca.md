# Orca Flash Next on HAL9000: prepared, not activated

This adds the **OrcaRouter Qwen3.8-Flash-Next uncensored IQ3_XXS** model through
Strata, alongside the existing Bonsai/Qwen llama-swap stack. It is an explicit
local compatibility workflow, not a replacement with the aligned GSQ-RCO weights
in Strata's installer menu. No upstream installer or host driver changes are used.

## Model and runtime selection

- [Orca model card](https://huggingface.co/orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF/tree/e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc):
  revision `e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc`, Apache-2.0 as declared by its publisher.
- [Strata Orca compatibility](https://github.com/Niko1221/Strata/blob/6f32ec070f23ced9f50e704d854d775da52591ab/docs/ORCA.md):
  IQ3_XXS is the specifically validated Orca quant. Other quants are not assumed
  interchangeable; IQ3_M includes unsupported Q5_0 down matrices in the native path.
- [Pinned Strata source](https://github.com/Niko1221/Strata/tree/6f32ec070f23ced9f50e704d854d775da52591ab):
  `6f32ec070f23ced9f50e704d854d775da52591ab`, version 0.1.39, MIT.
- Pinned llama.cpp GGML/gguf-py dependency:
  `3cf03257f219afbe7334045ff7c6a06ac68c627d`, as selected by this Strata revision.
- CUDA package versions and Python dependencies come from this repository's
  nixpkgs lock. The engine builds only for the RTX 4090's `sm_89`, with portable
  AVX2 CPU code rather than build-machine-specific instructions. This differs
  from the upstream pip environment but stays declarative and pinned.
- A minimal packaging patch treats unavailable psutil disk counters as missing
  telemetry. This avoids an upstream crash in the Nix sandbox; it does not alter
  inference or skip the server tests.

The two model shards total **85,202,668,032 bytes**. The provisioning helper
pins their revision and SHA256, resumes partial downloads, verifies the complete
shards before use, and packs the model's own tokenizer. `--compat-bf16` expands
small projections that the engine expects as BF16; this introduces rounding and
cannot recover the original full-precision checkpoint. Expert weights and the
28.8 GB disk-backed PLE lookup table retain their quantized form. Packed dense
weights require about 1.43 GiB. The original model's MTP head uses its upstream
pinned revision and tensor checksums; acceptance on this fine-tune still needs
measurement. No vision encoder/projector is configured: this setup is text-only.

## Hardware and resource limits

Read-only inspection on 2026-10-05 found:

| Resource | HAL9000                                                   |
| -------- | --------------------------------------------------------- |
| GPU      | RTX 4090, 24,564 MiB total, 3,236 MiB in use              |
| Driver   | NVIDIA 580.142                                            |
| CPU      | Intel i9-13900K, AVX2, 32 logical CPUs                    |
| RAM      | 62 GiB total, 27 GiB available; 7.1 GiB swap already used |
| Storage  | `/storage-fast`, 789 GiB free on ZFS                      |

The upstream-validated resident IQ3_XXS expert arena alone needs approximately
49.8 GiB RAM. The current **available** memory is insufficient for that mode.
The unit therefore refuses startup below **56 GiB MemAvailable**, while another
GPU compute process is resident, or while any of llama-swap, Ollama, Mold,
ComfyUI or InvokeAI is active. It never stops those services automatically.
A planned maintenance window or additional RAM is required before this default
can start. Total installed RAM is not the same as available RAM.

Strata also has `--mmap-experts` with `--resident-budget-gib N` and automatic
`--resident-experts` modes. These can trade disk I/O for less resident RAM, but
this integration retains the Orca-specific validated resident configuration.
Testing a bounded disk-mapped variant on HAL9000 would be a separate inference
experiment; it does not establish the screenshot's advertised throughput.
A smaller Orca 27B would be a different model, not equivalent to Flash Next.
No substitution has been made merely to claim that this large model fits.

## Service and API

`services.strata-orca.enable = true` installs a **manual** unit and tools into
HAL9000's next system closure. The unit has no `wantedBy`; activation would not
start it. `/etc/strata-orca.json` uses:

- OpenAI-compatible API at **`http://127.0.0.1:8081/v1`**, with model ID
  `orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs`.
- 32,768-token context, INT8 KV, 512-token prefill chunks, automatic expert cache.
- MTP proposals of up to 4 tokens with minimum probability 0.5.
- Persistent state under `/storage-fast/llm/strata-orca`, owned by `strata-orca`.

There is no new firewall opening or public listener. Existing llama-swap remains
on port 8080; the new model is deliberately not registered there, because a
request must not trigger loading a second GPU runtime or evict a production LLM.
Future remote use can tunnel the loopback API after authorized activation and
resource scheduling. The server serializes one resident sequence through a FIFO;
this is not the existing eight-slot Bonsai configuration.

## Reproducible provisioning, after separate activation approval

Build validation does not require an 85 GB download. The packaged command defaults
to a plan without downloads or mutations:

```sh
strata-orca-provision --dry-run
```

After a separately approved activation installs the tools and creates the service
user/directory, provision data explicitly as that user:

```sh
sudo -u strata-orca strata-orca-provision --provision
```

This downloads the immutable IQ3_XXS shards, verifies SHA256, makes the model's
compatibility pack/tokenizer, fetches and verifies the original MTP head,
quantizes its experts to Q2_0, exports the runtime, and installs the pinned
`draft_vocab.bin`. Budget at least 110 GB free disk. The helper does **not** start
services or activate NixOS. A custom data directory can be selected with
`STRATA_ORCA_DATA_DIR`, matching the module's `dataDir` setting.

## Validation and pending activation

Validation completed on 2026-10-05:

- Formatting/treefmt, shellcheck, and staged whitespace checks passed.
- `nix flake check --impure` passed on the local aarch64-darwin system (six
  checks; incompatible systems are omitted by that command).
- Strata's CUDA sm_89 binary built successfully with CUDA 12.8.93. All **23
  packing tests** and **139 mock-server tests** passed inside the Nix sandbox.
- Packaged server/packing CLI help and provisioning `--dry-run` passed. No model
  weights were downloaded, and real model inference was not run.
- `nix develop -c deploy-test hal9000` completed its remote full system build and
  **dry-activate**. Final rehearsal closure:
  `/nix/store/pgdis9gqic1zd1125mn4jcfjlbz7mqd8-nixos-system-hal9000-25.11.20260630.b6018f8`.
- `/run/current-system` remained
  `/nix/store/y3bl8zhph7myida4fmrqgbcdmbp5m575-nixos-system-hal9000-25.11.20260630.b6018f8`;
  llama-swap, Ollama and Mold remained active, and the new unit was absent from
  the running system. **No activation or service restart occurred.**

The rehearsal uses the committed baseline `flake.lock`, leaving the user's
unrelated lockfile edits untouched, and isolated staging on HAL9000. The
repository's `deploy-test` runs `nixos-rebuild build` then `dry-activate`;
**dry-activate does not activate a generation or run the inference unit**.

Pending steps requiring separate authorization:

1. Review this implementation and resource scheduling; choose a maintenance
   window/add RAM or approve an explicitly tested low-RAM configuration.
2. Activate the reviewed NixOS closure separately. No activation is performed here.
3. Run explicit model provisioning and confirm the prepared files/permissions.
4. Arrange GPU exclusivity and sufficient available RAM before manual startup.
5. Run real arithmetic/code/multiturn/streaming smoke tests; measure cold/warm
   prefill, decode, RAM/VRAM, MTP acceptance, and long-context behavior locally.
6. Decide whether any remote access or on-demand routing is appropriate.

Upstream reports a single short 77.7 token/s decode result on an RTX 5090 with
128 GB RAM. That is not a HAL9000 measurement. The screenshot's legal-score and
12 GB VRAM claims are anecdotal and do not establish accuracy or total memory
requirements. No local inference benchmark is claimed.
