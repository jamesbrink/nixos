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
The module preserves a full `resident` option with a **56 GiB MemAvailable**
guard. HAL9000 explicitly selects source-supported **`bounded-mmap`**: native
`--mmap-experts --resident-budget-gib 24`, with
`STRATA_RESIDENT_HEADROOM_GIB=8`. Its **36 GiB MemAvailable** startup guard covers
the 24 GiB expert budget, 8 GiB allocation headroom and 4 GiB for other runtime
buffers. Both modes apply the reviewed desktop/GPU startup guard below; the launcher
never stops independent services automatically.

The pinned native IQ loader retains the same quantized expert bytes and supports
budgeted residency for this pack: hot experts are held in RAM, uncached experts
are read from the immutable GGUF shards through the OS cache. This is an explicit,
independently source-reviewed configuration for the 64 GiB host, **not an
upstream Orca benchmark result**. Real inference and measured performance must
validate it. The configured budget is an upper bound: allocation can be smaller,
or fail over to mmap-only operation. Benchmark artifacts require and preserve
the actual startup allocation/fallback marker; they cannot present configured
budget as measured resident memory.

The full resident mode remains available via
`services.strata-orca.memoryMode = "resident"`. Budget and headroom are explicit
positive-GiB options, and the bounded preflight follows their sum plus 4 GiB.

## Shared endpoint and lifecycle

Clients keep **`http://hal9000:8080/v1`** and select exactly
**`orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs`**. Bonsai and Qwen retain
`bonsai-2-27b` and `qwen3.8-27b`. There are no aliases or extra public listeners. Strata explicitly accepts the
preserved `hal9000` and `hal9000.home.urandom.io` Host headers; IP/localhost
clients are accepted upstream. Additional trusted DNS names can be configured
with `services.strata-orca.allowedHosts`, without disabling the Host guard.

The existing pinned llama-swap v249 (commit
`f94c94ac61a142f15a4d156015bfb8c0511b3bbb`) starts the Orca launcher as a managed
child, proxies it at `127.0.0.1:18081`, and polls `/health`. Port 8081 is already
owned by HAL9000's pgweb service and is preserved. Strata is eager within
that child: its HTTP listener appears only after engine initialization. The
configurable `services.strata-orca.readinessTimeout` defaults to 900 seconds,
covering cold initialization. Do not enable Strata's separate lazy/idle-unload
settings: llama-swap owns both lifetimes.

All three models belong to llama-swap's existing **exclusive default group**.
It waits for the previous process to stop before starting the next. The launcher
checks actual GPU compute PIDs after that stop, and never refuses simply because
its parent llama-swap service is active. It does not stop Mold, Ollama, or desktop
services automatically. Independent GPU workloads must release their resources
before loading Orca. The selected 36 GiB available-RAM guard remains in force.

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

The immutable Orca shard URL requires publisher access approval. Earlier on 2026-10-05,
unauthenticated requests returned HTTP 401; HAL9000's existing Hugging Face token
returned **HTTP 403, account not in the authorized list**. Access was subsequently
granted by the user and authenticated pinned-shard requests succeeded; provisioning
is now in progress. The token can access
the pinned original Qwen MTP head. Access is now resolved; completed hash-verified provisioning and real inference
are still prerequisites before claiming a runnable deployment or benchmark.

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
Eight benchmark evidence/plan checks reject failed/truncated streams and stale or
concurrent timing evidence. Output-limit incomplete responses are labeled;
telemetry failures mark a benchmark incomplete. Independent Codex peer review
verified lifecycle, recipe, authentication and benchmark evidence against pinned
upstream sources, independently reran the authentication and benchmark checks, and found no
remaining material code issues after the benchmark corrections.

A runnable real deployment and benchmark require completed authenticated
provisioning, reviewed activation and a successful live memory preflight. The user authorized deployment after independent Codex
review, and temporary Mold/graphical-session stop during benchmarking. The
original state must be recorded and restored; SSH/access and unrelated services
must remain intact. Read-only inspection found approximately **16 GiB ZFS ARC**
(`c_max = 17179869184`), so freeing Mold/desktop alone may not satisfy the RAM
guard. Any temporary ARC cap must be reviewed, measured, and restored as well.
HAL9000 explicitly selects the reviewed bounded mmap mode above. A temporary ARC
change is unnecessary if its 36 GiB preflight is already satisfied. Do not disable
the guard.

The benchmark runner is prepared, not a completed measurement:

```sh
python3 scripts/test-strata-llama-swap.py /run/current-system/sw/bin/llama-swap
python3 scripts/test-benchmark-strata-orca.py
python3 scripts/test-strata-memory-modes.py
python3 scripts/benchmark-strata-orca.py \
  --output docs/benchmarks/orca-20261005.json
```

Run the latter on HAL9000 only after verified model provisioning and reviewed
activation. It sends benign code/prose and two longer prompts through the shared
Responses API, three trials each, recording cold-engine vs warm-prefix trials,
deployed memory mode/budget and measured allocation/fallback, actual prompt/output/reasoning counts, time to first token and answer, request
wall time, Strata engine prompt/decode timing and MTP acceptance, native RSS,
available RAM, and VRAM. First observed backend readiness approximates load
latency separately from prompt processing. Cold engine does not mean cold disk
cache. Exact context depth comes from usage, not the prompt's character label.
Concurrency is deliberately excluded from throughput claims because Strata runs
one sequence. Save model-switch/UAT logs and restored service state alongside
the artifact. No real benchmark numbers have yet been obtained.

Upstream reports a single short 77.7 token/s decode result on an RTX 5090 with
128 GB RAM. That is not a HAL9000 measurement. The screenshot's legal-score and
12 GB VRAM claims are anecdotal and do not establish accuracy or total memory
requirements. No local inference benchmark is claimed.

## Performance tuning, after provisioning and first successful inference

The pinned native IQ **server requires MTP and `--spec >= 2`**; its guards reject
MTP-off and spec 1. An off/on claim would be misleading for this runtime. `--spec T`
is the verify-window size, permitting at most **T−1 draft tokens**. Screen windows
2/3/4/6 with `--suffix-draft 0`, fixed `--spec-min-p 0.5` and matching
`--mtp-max-t T`, then compare suffix 0 against suffix 3 separately. The default
suffix 3 can extend the overall verify window by two (cap 8); keep this distinct
from the MTP window and report engine draft acceptance.

Generate one-factor candidate files without starting anything:

```sh
python3 scripts/plan-strata-orca-tuning.py --config /etc/strata-orca.json \
  --phase mtp --output /storage-fast/llm/strata-orca/tuning/mtp
```

Carry the selected candidate into `--config` for subsequent phases. Screen MTP
first, then prefill 512/1024/2048, capacities 16K/32K/64K, and suffix separately.
Keep INT8 KV, budget 24 and auto GPU cache initially. Higher capacities allocate
more KV/state at the expense of GPU expert cache; the MTP window stays at most
32768 in these candidates. Use identical varied retrieval prompts across capacity
comparisons; only later use `--long-records 700` for deeper 32K/64K finalists.
Actual usage tokens, not character count, establish tested depth.

Optional RAM 24/28/32 GiB candidates require startup guards 36/40/44 GiB, respectively.
Skip infeasible budgets rather than lowering the guard. Optional GPU-cache caps
are 75%/50% of **measured auto expert slots** (`--phase gpu-cache --auto-cache-slots N`),
not GiB. Parser-supported KV variants are fp16/int8/q4_0/k8v4; only int8 has the Orca
recipe's evidence. Reduced-KV candidates require answer/retrieval-quality review
alongside speed and memory; fp16 may leave insufficient 4090 VRAM.

For each candidate, use the existing llama-swap service and endpoint with an
explicit **temporary runtime configuration**, preserving a copy of its baseline
configuration and unit command. Place candidate files and the child launcher in
the existing private model-data directory, accessible to the service's group.
Copy `strata-gpu-guard.py` beside the candidate child launcher. Clone the
generated llama-swap YAML and change only this model's `cmd` to an
absolute Python interpreter plus `run-strata-orca-candidate.py CANDIDATE.json`.
Keep the same model ID, proxy 18081, group/exclusivity and readiness/unload timeouts.
A temporary systemd runtime override can point llama-swap's existing command at
that YAML. Record and restore the original command after screening. Inspect its
actual unit flags before constructing the override; do not guess them.

The candidate launcher enforces the candidate's dynamic RAM guard and reviewed GPU
startup policy, exports the reviewed 8 GiB headroom, and **execs** the same packaged
server in llama-swap's process group. Use supported unload before switching;
verify no child/GPU resources remain. This temporary change is within authorized
testing, not a permanent winner configuration. Do not run a competing independent
inference server or alter production configuration files in place.

Screen one trial each of code/prose/varied long retrieval with one cold start per
candidate (`--cold-policy once`), then repeat the best
stable finalists three times with cold and warm trials:

```sh
python3 scripts/benchmark-strata-orca.py --config CANDIDATE.json --trials 1 --cold-policy once \
  --workloads code,prose,context_varied_long --output candidate-screen.json
```

The benchmark reads actual candidate flags, headroom and mode; it requires a
cold-start allocation/fallback log and records exact retrieval answers and
correctness. Select a stable finalist using latency, prompt/decode throughput,
correct retrieval, draft acceptance, RAM/VRAM and startup/switch cost. Record
failures and skip reasons. Commit and independently review the winning permanent
settings, restore baseline testing overrides, deploy that reviewed winner, then
verify shared-endpoint lifecycle and existing-model operation again.

## Desktop coexistence and GPU startup policy

The module's desktop compute allowlist defaults to **empty**, so unreviewed hosts
retain zero-compute-client startup. HAL9000 explicitly allows only executable
basename `walker` (observed 268 MiB), with an **aggregate 512 MiB limit** across all
allowed compute PIDs and an actual **20,480 MiB free-VRAM floor** on GPU0. Unknown
compute names, other LLM servers, and Mold/Python compute processes are refused
regardless of current utilization. Missing/N/A PID or memory measurements fail
closed. Graphics allocations are covered by the measured free-VRAM floor.

Native `--vram-reserve-mib 2048` holds two GiB out of auto expert-cache sizing after
model/session/MTP allocations and prevents the pinned engine from automatically
reducing the reserve toward 300 MiB. This is a reviewed starting policy, not proof
of desktop responsiveness; restored-graphics trials must measure remaining VRAM
and representative desktop activity. The candidate launcher uses the same shared
guard and cannot lower the reserve/free floor or expand the reviewed allowlist.
Benchmarks record the explicit reserve and startup policy alongside resource use.

The startup check cannot predict future allocations. **Concurrent Mold generation
and Orca inference are unsupported** without GPU dispatch coordination. Mold must
release its GPU context before Orca starts if it has allocated compute memory;
restarting Mold may release it, but this must be verified live. Idle 0% GPU usage
is insufficient evidence. This change adds no Mold queue hooks or automatic stops.

Five focused guard tests cover allowed small desktop clients, strict defaults,
unknown engines, aggregate VRAM, the free-memory boundary and invalid measurements:

```sh
python3 scripts/test-strata-gpu-guard.py
```

## Native phase accounting and finalist quality gates

The 64-token reasoning budget can cause two native calls: reasoning, then a
server-injected wrap-up followed by the answer. API usage counts the injected
text, while the pinned wrapper's `last_timings` combines total API `predicted_n`
with the **last native phase's** cache and decode clock. Its cache can therefore
exceed the original input count. Never divide total API output by that last clock,
or interpret the continuation cache as initial-prefix reuse.

The runner now parses each request's native log phases, validates original input
against the first phase and final cache/clock against fresh wrapper status, and
retains all counters. It reports all-phase native throughput, last-phase native
throughput, API output/reasoning/answer counts and request-wall rates separately.
Native counts can include cancellation/drain overrun; API-minus-native counts
are not automatically all injected text. Cold log windows select the latest
native-start marker; warm windows read only bytes appended for that request.

Compare saved artifacts locally without touching inference:

```sh
python3 scripts/compare-strata-orca-benchmarks.py candidate-a.json candidate-b.json   --output comparison.json
```

The helper groups identical prompt sets/model/runtime and separates cold-engine,
warm-engine/fresh-prefix, partial-prefix and fully-cached-prefix trials using
**initial native phase** evidence. Automatic gates reject failed/incomplete
measurements, truncated/missing answers, incorrect or untested retrieval,
unexpected allocation fallback, missing allocation evidence and resource warnings.
Code functionality and prose correctness still require explicit human review;
passing retrieval does not prove general answer quality.

Prefer repeatably lower answer/request latency without material regressions on
other representative workloads; native throughput and draft acceptance explain
those timings. Require at least three finalist trials, no OOM/stalls, measured
RAM/VRAM headroom, and verified cold start/model switching/desktop behavior before
selecting permanent settings. A single screening trial only identifies a shortlist.
