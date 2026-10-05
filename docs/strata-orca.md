# Orca Flash Next through the shared llama-swap API

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
The launcher therefore refuses startup below **56 GiB MemAvailable** or while
another GPU compute process is resident. It never stops independent services
automatically, and does not reject an idle Ollama or its own llama-swap parent.
A planned maintenance window or additional RAM is required before this default
can start. Total installed RAM is not the same as available RAM.

Strata also has `--mmap-experts` with `--resident-budget-gib N` and automatic
`--resident-experts` modes. These can trade disk I/O for less resident RAM, but
this integration retains the Orca-specific validated resident configuration.
Testing a bounded disk-mapped variant on HAL9000 would be a separate inference
experiment; it does not establish the screenshot's advertised throughput.
A smaller Orca 27B would be a different model, not equivalent to Flash Next.
No substitution has been made merely to claim that this large model fits.

## Shared endpoint and lifecycle

Clients keep **`http://hal9000:8080/v1`** and select exactly
**`orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs`**. Bonsai and Qwen retain
`bonsai-2-27b` and `qwen3.8-27b`. There are no aliases or extra public listeners. Strata explicitly accepts the
preserved `hal9000` and `hal9000.home.urandom.io` Host headers; IP/localhost
clients are accepted upstream. Additional trusted DNS names can be configured
with `services.strata-orca.allowedHosts`, without disabling the Host guard.

The existing pinned llama-swap v249 (commit
`f94c94ac61a142f15a4d156015bfb8c0511b3bbb`) starts the Orca launcher as a managed
child, proxies it at `127.0.0.1:8081`, and polls `/health`. Strata is eager within
that child: its HTTP listener appears only after engine initialization. The
configurable `services.strata-orca.readinessTimeout` defaults to 900 seconds,
covering cold initialization. Do not enable Strata's separate lazy/idle-unload
settings: llama-swap owns both lifetimes.

All three models belong to llama-swap's existing **exclusive default group**.
It waits for the previous process to stop before starting the next. The launcher
checks actual GPU compute PIDs after that stop, and never refuses simply because
its parent llama-swap service is active. It does not stop Mold, Ollama, or desktop
services automatically. Independent GPU workloads must release their resources
before loading Orca. The 56 GiB available-RAM guard remains in force.

The launcher ends with `exec`; Strata's native child inherits llama-swap's POSIX
process group. v249 sends SIGTERM to that group and escalates to SIGKILL on
expiry. Strata also handles SIGTERM through its engine cleanup path. TTL is
600 seconds; configured idle-unload grace is 75 seconds. Model switches use
v249's global readiness deadline for stopping as well as starting. Systemd stops
the complete llama-swap cgroup if shutdown exceeds 90 seconds. A GPU-free test
with deliberately stubborn children verifies forced cleanup and that switching
never leaves the old model's process tree resident.

Persistent data remains under `/storage-fast/llm/strata-orca`. The provisioning
user owns it, and llama-swap's dynamic user receives only the supplemental model
data group and this directory as an additional write path. Its private user
namespace is disabled so the host group is usable; existing filesystem/process
protection otherwise remains. The former independent `strata-orca.service` is
removed: the model has one owner, llama-swap. No standalone backend should be
started beside it.

The config uses a 32,768-token context, INT8 KV, 512-token prefill chunks,
automatic expert cache, and MTP proposals of up to four tokens at minimum
probability 0.5. It is text-only and serializes one sequence through a FIFO;
concurrency queues requests rather than multiplying resident sequences.

Primary lifecycle sources:
[llama-swap process groups](https://github.com/mostlygeek/llama-swap/blob/f94c94ac61a142f15a4d156015bfb8c0511b3bbb/internal/process/runtime_unix.go),
[stop-before-start router](https://github.com/mostlygeek/llama-swap/blob/f94c94ac61a142f15a4d156015bfb8c0511b3bbb/internal/router/base.go),
and [Strata server cleanup](https://github.com/Niko1221/Strata/blob/6f32ec070f23ced9f50e704d854d775da52591ab/serve/server.py).

## Reproducible provisioning and access prerequisite

Build validation does not require an 85 GB download. The packaged command defaults
to a plan without downloads or mutations:

```sh
strata-orca-provision --dry-run
```

The immutable Orca shard URL currently requires access approval. On 2026-10-05,
unauthenticated requests returned HTTP 401; HAL9000's existing Hugging Face token
returned **HTTP 403, account not in the authorized list**. The token can access
the pinned original Qwen MTP head. Request access to the exact Orca model from
its publisher before claiming a runnable deployment or benchmark.

Provisioning accepts `STRATA_HF_TOKEN_FILE`; curl reads a temporary mode-0600
header file, and the MTP helper reads the token file without placing credentials
in command arguments/logs. Its HTTP redirects strip authorization across hosts
or HTTPS downgrades. There is no token in the inference service environment.
After tools/account creation, an administrator can provision with the existing
root-readable agenix token and then normalize ownership:

```sh
sudo env STRATA_HF_TOKEN_FILE=/run/agenix/huggingface-token strata-orca-provision --provision
sudo chown -R strata-orca:strata-orca /storage-fast/llm/strata-orca
sudo chmod 0770 /storage-fast/llm/strata-orca
```

This downloads the immutable IQ3_XXS shards, verifies SHA256, makes the model's
compatibility pack/tokenizer, fetches and verifies the original MTP head,
quantizes its experts to Q2_0, exports the runtime, and installs the pinned
`draft_vocab.bin`. Budget at least 110 GB free disk. The helper does **not** start
services or activate NixOS. A custom data directory can be selected with
`STRATA_ORCA_DATA_DIR`, matching the module's `dataDir` setting.

## Validation, review, and benchmark status

Validation completed on 2026-10-05:

- Formatting/treefmt, shellcheck, and staged whitespace checks passed.
- `nix flake check --impure` passed on the local aarch64-darwin system (six
  checks; incompatible systems are omitted by that command).
- Strata's CUDA sm_89 binary built successfully with CUDA 12.8.93. All **23
  packing tests** and **139 mock-server tests** passed inside the Nix sandbox.
- Packaged server/packing CLI help and provisioning `--dry-run` passed. No model
  weights were downloaded, and real model inference was not run.
- `nix develop -c deploy-test hal9000` completed its remote full system build and
  **dry-activate**. Shared-route rehearsal closure (before the final Host allowlist refinement):
  `/nix/store/7wxla3m3zd4nmsin6snmf9xmmqng0kyn-nixos-system-hal9000-25.11.20260630.b6018f8`.
- `/run/current-system` remained
  `/nix/store/y3bl8zhph7myida4fmrqgbcdmbp5m575-nixos-system-hal9000-25.11.20260630.b6018f8`;
  llama-swap, Ollama and Mold remained active, and the new unit was absent from
  the running system. **No activation or service restart occurred.**

The rehearsal uses the committed baseline `flake.lock`, leaving the user's
unrelated lockfile edits untouched, and isolated staging on HAL9000. The
repository's `deploy-test` runs `nixos-rebuild build` then `dry-activate`;
**dry-activate does not activate a generation or run the inference unit**.

The shared-endpoint update also passes a GPU-free lifecycle test against the
actual v249 binary. It verifies three-model listing, exact ID forwarding,
eager readiness, SSE, Bonsai/Orca/Qwen exclusive switches, forced native-child
cleanup, TTL unloading, reloading, and llama-swap shutdown. Authentication has
three offline regression checks for missing tokens, host scoping, and redirects.
Four benchmark evidence checks reject failed/truncated streams and stale or
concurrent timing evidence. Output-limit incomplete responses are labeled;
telemetry failures mark a benchmark incomplete. Independent Codex peer review
verified lifecycle, recipe, authentication and benchmark evidence against pinned
upstream sources, independently reran all seven offline checks, and found no
remaining material code issues after the benchmark corrections.

A runnable real deployment and benchmark remain blocked by the publisher's
Orca access restriction. The user authorized deployment after independent Codex
review, and temporary Mold/graphical-session stop during benchmarking. The
original state must be recorded and restored; SSH/access and unrelated services
must remain intact. Read-only inspection found approximately **16 GiB ZFS ARC**
(`c_max = 17179869184`), so freeing Mold/desktop alone may not satisfy the RAM
guard. Any temporary ARC cap must be reviewed, measured, and restored as well.
Do not disable the guard or silently switch to an unvalidated mmap configuration.

The benchmark runner is prepared, not a completed measurement:

```sh
python3 scripts/test-strata-llama-swap.py /run/current-system/sw/bin/llama-swap
python3 scripts/test-benchmark-strata-orca.py
python3 scripts/benchmark-strata-orca.py \
  --output docs/benchmarks/orca-20261005.json
```

Run the latter on HAL9000 only after verified model provisioning and reviewed
activation. It sends benign code/prose and two longer prompts through the shared
Responses API, three trials each, recording cold-engine vs warm-prefix trials,
actual prompt/output/reasoning counts, time to first token and answer, request
wall time, Strata engine prompt/decode timing and MTP acceptance, native RSS,
available RAM, and VRAM. First observed backend readiness approximates load
latency separately from prompt processing. Cold engine does not mean cold disk
cache. Exact context depth comes from usage, not the prompt's character label.
Concurrency is deliberately excluded from throughput claims because Strata runs
one sequence. Save model-switch/UAT logs and restored service state alongside
the artifact. No real benchmark numbers have been obtained while access is blocked.

Upstream reports a single short 77.7 token/s decode result on an RTX 5090 with
128 GB RAM. That is not a HAL9000 measurement. The screenshot's legal-score and
12 GB VRAM claims are anecdotal and do not establish accuracy or total memory
requirements. No local inference benchmark is claimed.
