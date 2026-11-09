# Strata models on HAL9000

[Strata](https://github.com/Niko1221/Strata) runs Qwen3.8-Flash-Next (180B
total: 125B MoE with 6B active per token, a 51B n-gram/PLE table and a 4B MTP
head) on the RTX 4090 by keeping hot experts in VRAM, a bounded set in RAM and
the rest memory-mapped from the root SSD. Every model below is the original
(non-fine-tuned) model; the earlier Orca fine-tunes were retired on 2026-11-03
(history: [strata-orca.md](strata-orca.md)).

## Models

All three share the llama-swap endpoint `http://hal9000:8080/v1`; only one is
resident at a time, so switching reloads and drops the prompt cache.

| llama-swap ID (OMP role)                                 | Files                                | Port  | Upstream rating             |
| -------------------------------------------------------- | ------------------------------------ | ----- | --------------------------- |
| `qwen3.8-flash-next-q2_0` (`@flash-q2`, hal9000 default) | ISTA-DASLab GSQ-RCO Q2_0, 66.4 GB    | 18083 | fastest, good               |
| `qwen3.8-flash-next-iq3_xxs` (`@flash-iq3`)              | ISTA-DASLab GSQ-RCO IQ3_XXS, 75.8 GB | 18081 | slower, great               |
| `qwen3.8-flash-next-ud-q4_k_xl` (`@flash-q4`)            | Unsloth UD-Q4_K_XL, 111.3 GB         | 18082 | 4-bit, between IQ3_S and Q5 |

ISTA's second shard (the 28.8 GB PLE table) is identical in every ISTA size;
provisioning hard-links it instead of downloading it again.

## Configuration

- `modules/services/strata/default.nix` (`services.strata`): one set of tuning
  and admission guards for every model, per-model launchers, llama-swap
  entries, `strata-provision` and `strata-monitor`. Generated server configs
  are visible at `/etc/strata/<id>.json`.
- `modules/services/strata/catalog.nix`: pinned files (URL with revision,
  SHA256, size, PLE shard, pack arguments) as upstream v0.2.10 `setup.py`
  pins them. Also lists ISTA IQ2_XS and IQ3_S.
- `hosts/hal9000/default.nix`: picks catalog entries and ports under
  `services.strata.models`, and sets the shared tuning. `contextTokens`
  (262144 = 256K, the model's native limit) is the one context switch for
  all models; match OMP's `contextWindow` in the `omp-config` repo.

Adding a model: add (or reuse) a catalog entry, add it to
`services.strata.models` with a free port, deploy, then provision it. The
monitor, provisioning and llama-swap pick it up from the module.

## Data layout

`/var/lib/strata` (root SSD, Corsair MP600/ext4), owned by the `strata` user:

- `mtp/rt`: the original Qwen MTP draft head (revision `de4b8e4d`), shared.
- `mmproj-Qwen3.8-Flash-Next-BF16.gguf`: the base model's vision projector.
- `<id>/`: the model's shards, `pack/` (with `tokenizer/`) and `strata.log`.

## Operations

```sh
strata-provision                                  # plan: what is missing
sudo -u strata strata-provision --provision       # all models
sudo -u strata strata-provision --provision qwen3.8-flash-next-q2_0
strata-monitor                                    # follows the loaded model
```

`strata-provision` verifies every SHA256 once and leaves a `<file>.sha256`
marker; it never starts services. `strata-monitor` asks llama-swap which
Strata model is loaded, opens `strata-cli monitor` on its port, reopens it on
a model switch and waits while a llama.cpp model is loaded. Never reach a
backend through llama-swap's `/upstream/<id>/` path: that loads the model.

## Guards and tuning (HAL9000)

Bounded mmap with a 24 GiB expert budget and 8 GiB headroom; a launch needs
36 GiB `MemAvailable` and 18 GiB free VRAM (`minimumFreeVRAMMiB`), with a
2304 MiB native VRAM reserve. Desktop CUDA clients chrome, mpv, swayosd-server
and walker are allowed within 1024 MiB. INT8 KV, prefill 2048, 23 pool
workers, MTP window 4 with a 32K draft window, suffix drafting off, GPU vision
encoder. These settings were tuned on Orca IQ3_XXS (see the dated reports
linked from [strata-orca.md](strata-orca.md)) and carry over unchanged,
except KV: FP16 until 2026-11-09, then INT8 for 256K. Strata allocates K/V
for the whole context up front out of the GPU expert cache; INT8 is about
13.7 KB per token, so 256K INT8 takes the same VRAM as 128K FP16 did.

## Status (2026-11-03)

First checks after provisioning, 128K context, Strata v0.2.10 (single short
runs, not a benchmark):

| Model      | Cold start + first answer | Decode                                                |
| ---------- | ------------------------- | ----------------------------------------------------- |
| Q2_0       | 36 s                      | ~124 tok/s (short reply)                              |
| IQ3_XXS    | 38 s                      | ~64 tok/s (short reply)                               |
| UD-Q4_K_XL | 36 s                      | 10 tok/s cold, 23-26 tok/s warm on ~250-token answers |

All answered an arithmetic check correctly and used about 22.1 GiB of VRAM.
UD-Q4_K_XL's 77 GB of experts exceed the 24 GiB RAM budget, so it reads the
most from the SSD and is the slowest. The old Orca data was deleted.
