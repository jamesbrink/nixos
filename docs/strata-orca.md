# Orca Flash Next through the shared llama-swap API

This adds the **OrcaRouter Qwen3.8-Flash-Next uncensored IQ3_XXS** model through
Strata, alongside the existing Bonsai/Qwen llama-swap stack. It is an explicit
local compatibility workflow, not a replacement with the aligned GSQ-RCO weights
in Strata's installer menu. No upstream installer or host driver changes are used.

## Additional Q4_K_M selection

The recommended publisher Q4_K_M is a separate selection,
`orcarouter-qwen3.8-flash-next-uncensored-q4_k_m`, alongside the unchanged
IQ3_XXS model ID. It uses `/var/lib/strata-orca-q4_k_m` on the root MP600 SSD,
its own compatibility pack/tokenizer/log, and private Strata port 18082.
Both inherit the same 65536 target context, 32768 MTP window, FP16 KV,
2048 prefill, 23 expert workers, spec4, 24GiB expert residency, RAM/GPU guards,
exclusive llama-swap selection, and 600-second idle unload. The verified
original-model MTP runtime is shared from `/var/lib/strata-orca/mtp/rt`.
Only one variant can be resident; changing selection reloads it and drops
its prompt cache. OMP uses `orca-q4` for Q4 and `orca` for existing IQ3,
with 65536 context and 8192 maximum output for both.

The three immutable shards at publisher revision
`e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc` total **119,150,722,944 bytes**
(119.15GB, about 111GiB), around 40% more than the existing IQ3 weights.
The model card's ~110GB estimate is not the exact pinned artifact size.
See the [pinned shard sizes and SHA256 manifest](models/orca-q4-k-m-manifest.json).
`Q4_K_M` is a mixed quantization: all 48 expert gate/up matrices are Q4_K,
while down matrices are Q5_0 or Q8_0, and the PLE table is Q5_0. These actual
GGUF formats are supported by the pinned Strata kernel dispatch and PLE
reader. Do not infer compatibility from the generic quantization name alone:
Q4_K or Q6_K down kernels are absent in this engine, but these shards do not
use them. Preparation keeps expert precision unchanged; `--compat-bf16`
expands only the required small projections, as with IQ3. Higher precision
and file size do not establish improved answer quality or speed without tests.

`strata-orca-q4-provision` defaults to a plan. To reproduce provisioning:

```sh
sudo env STRATA_HF_TOKEN_FILE=/run/agenix/huggingface-token strata-orca-q4-provision --provision
sudo chown -R strata-orca:strata-orca /var/lib/strata-orca-q4_k_m
sudo chmod 0770 /var/lib/strata-orca-q4_k_m
```

This verifies each pinned SHA256 and makes the quantization's own native
pack/tokenizer. It requires the existing IQ3 MTP runtime for serving, and does
not activate NixOS. The declarations are in `modules/services/orca-q4` and
HAL's enable flag; the primary `contextTokens` setting controls both variants.

### Q4 deployment acceptance (2026-10-05)

Deployed source `9d9dfdef88e0129fefb4c5b7da6314c957b3c732` as generation 1316,
with system/profile pointing to
`/nix/store/887q2fya29bykad3rjbbrk2r1nz1vcbv-nixos-system-hal9000-25.11.20260630.b6018f8`.
All three publisher SHA256 hashes passed. All three mapped GGUF paths were
verified on the root SSD. The model-isolation/tuning test, system build,
dry activation, and 23 encrypted-input/runtime metadata checks passed.
llama-swap, Mold, display-manager, Ollama and pgweb remained active after
activation. The root filesystem has about 98GiB free (94% used); allow
headroom before adding more weights. The default provisioning helper now
checks remaining download space plus 8GiB before transferring.

The shared API returned HTTP 200 and `77` for 7 times 11 in **70.023s**,
including first model startup. Native timing: 27 prompt tokens at 7.0 tok/s,
3 generated tokens at 3.9 tok/s, and 3/3 accepted draft tokens. The subsequent
real local OMP `orca-q4` invocation also returned `77`: 474 prompt tokens at
39.6 tok/s, 3 generated tokens at 7.1 tok/s, and 3/3 accepted drafts.
These very short replies are smoke checks, not statistically useful decoding
benchmarks or a matched comparison with IQ3. Download/hash/pack operations
influenced filesystem cache; neither request is an SSD cold-cache benchmark.
64K is configured and reported by the backend; a full 64K prompt was not tested
in this acceptance run. Startup confirmed 4640 GPU expert slots (14.13GiB),
24GiB page-locked RAM experts, and 1731MiB free VRAM after loading.
See [machine-readable acceptance evidence](benchmarks/orca-q4-deployment-20261005.json).

Local OMP now has a separate `orca-q4` role with the same 65536 context,
8192 output cap, reasoning/effort and tool compatibility as `orca`. Both
existing Orca and Bonsai/Qwen selections remain. Restart an existing OMP
session to refresh its configuration, then use `omp --model orca-q4`.
Use `omp --model orca` to return to IQ3. Selecting another model unloads the
previous backend; the normal 600-second idle unload applies to Q4 too.
Private local config backups were taken; credentials are not stored here.

## Root SSD relocation (deployed)

The HAL9000 configuration selects `services.strata-orca.dataDir = "/var/lib/strata-orca"`.
This is on the root ext4 filesystem, `/dev/nvme0n1p5`, backed by the
2TB Corsair Force MP600. The previous `/storage-fast/llm/strata-orca` directory
is on the Crucial P3 4TB NVMe and ZFS. After the user confirmed the SSD move,
the redundant `models`, `pack`, and `mtp` directories were removed on
2026-10-05 (about 88GiB of duplicate data). Historical benchmark artifacts
and the old log remain there. Only Orca was relocated. All 54 copied files (93,678,695,108 bytes) passed
SHA-256 comparison; both GGUF shards matched their pinned publisher hashes.
The root SSD retained approximately 211GiB free after the copy.

Activated on 2026-10-05 from base `main` revision `0fd606b` plus the local
uncommitted host override, using a full staging tree with pinned submodules.
The active system and system profile are
`/nix/store/xq4139azfc5nmp97585b55c55x6gdzaw-nixos-system-hal9000-25.11.20260630.b6018f8`.
The build, flake evaluation, dry activation, and all 23 encrypted-input/runtime
metadata checks passed. Only llama-swap and tmpfiles setup restarted; the five
previously checked services remained active. Activation preceded committing
the override, at the user's request. The user subsequently confirmed much
faster responses and requested keeping this location and committing/pushing
the configuration. This is user-observed performance, not a matched benchmark.
The real shared-endpoint request returned `77` with HTTP 200 in 70.688s,
including model startup. The engine's mapped GGUF files were verified on
the root SSD, and the backend reported 65536 context. This was an engine-cold
acceptance check with filesystem caches affected by copying/hashing, not a
matched performance comparison against the previous drive. Orca was left
loaded for user testing. See [root SSD acceptance evidence](benchmarks/orca-root-ssd-deployment-20261005.json).

Copy the model shards, compatibility pack/tokenizer, and complete MTP directory
with ownership and permissions preserved before activating a new `dataDir`.
Verify copied file hashes, then deploy. The module derives the native model,
pack, MTP, tokenizer, working directory, log and service write permissions from
this setting. No symlink back to storage-fast is needed. Future provisioning
must use `STRATA_ORCA_DATA_DIR=/var/lib/strata-orca`; changing the configuration
does not itself copy or download weights. Before rolling back to a generation
that uses the old directory, restore the model/pack/MTP data to that path
first; those redundant runtime assets have been removed.

The root SSD is faster-rated, but actual inference performance on it must be
measured. Earlier benchmark results describe the original ZFS location and
must not be presented as measurements of the new storage configuration.

## Deployed 64K context and client settings

HAL9000 now selects `services.strata-orca.contextTokens = 65536` in
`hosts/hal9000/default.nix`. The initial 64K configuration was activated on 2026-10-05 from committed
`main` revision `d41b56e`, preserving the newer Mold update. That deployment's system
and profile pointed to
`/nix/store/8c3pbks0wi6grpxzmabch75lql1zmwd0-nixos-system-hal9000-25.11.20260630.b6018f8`.
All 23 encrypted activation inputs and runtime secret metadata checks passed.
Dry activation restarted only llama-swap; Mold's unit was unchanged. The real
backend reports 65536 native context and returned `77` for the arithmetic check.
That cold request took 175.056s including startup. The OMP request also returned
`77` after its catalog was updated to 65536 context and 8192 maximum output.
Mold, display-manager, llama-swap, Ollama and pgweb remained active. See
[deployment acceptance evidence](benchmarks/orca-64k-deployment-20261005.json).
The historical 32K production benchmark report is unchanged.

To switch context later, edit only `contextTokens` in the HAL configuration:
`32768` for 32K or `65536` for 64K. The shared module generates the native
`--max-context` argument. Keep `mtpWindowTokens = 32768`: the draft context is
independent of the target window, and drafting worked above 32K target depth.
128K is not hardware-validated by these results.

The measured 7-worker context screen used the same 12890-token prompt: fresh
prefill was 33.910s at 32K and 37.097s at 64K; cached request wall time was
3.062s and 3.381s respectively. GPU expert slots fell from 7857 to 7426
(431 fewer, 5.5%). The 64K deep test retrieved all four facts exactly twice
from 59469 input tokens. These are screening measurements, not a benchmark of
the deployed 64K/23-worker production combination. See the
[complete context results](benchmarks/orca-20261005.md#context-capacity-and-automatic-expert-cache-tradeoff).

All other selected settings remain FP16 KV, prefill 2048, 23 expert workers,
MTP verification window/cap 4, suffix lookup 0, 24GiB resident budget,
8GiB allocation headroom, 36GiB available-RAM admission guard, 20480MiB
free-VRAM admission guard and 2048MiB native VRAM reserve. Increasing context
consumes session memory; automatic expert-cache sizing compensates by
reducing GPU expert slots. Do not interpret unchanged total VRAM as unchanged
cache capacity or guaranteed speed.

When changing context in the future, activate the server first and confirm
its reported native context, then match the Orca override's `contextWindow`
in local `~/.omp/agent/models.yml` and restart OMP. It now uses `65536`.
Keep `maxTokens: 8192`, not `65536`: input, tool definitions, reasoning and
output all share the total window. At 64K, an 8K output cap leaves at most
57344 tokens for input before template overhead; compact well before that
boundary. Existing OMP sessions must reload the model configuration.

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
pinned revision and tensor checksums; acceptance on this fine-tune was measured in the dated local benchmark report, including the zero-proposal control. No vision encoder/projector is configured: this setup is text-only.

## Hardware and resource limits

Historical read-only predeployment inspection on 2026-10-05 found:

| Resource | HAL9000                                                   |
| -------- | --------------------------------------------------------- |
| GPU      | RTX 4090, 24,564 MiB total, 3,236 MiB in use              |
| Driver   | NVIDIA 580.142                                            |
| CPU      | Intel i9-13900K, AVX2, 32 logical CPUs                    |
| RAM      | 62 GiB total, 27 GiB available; 7.1 GiB swap already used |
| Storage  | `/storage-fast`, 789 GiB free on ZFS                      |

The upstream-validated resident IQ3_XXS expert arena alone needs approximately
49.8 GiB RAM. That snapshot did not meet the resident guard. Final restored-state availability was 53.37GiB, still below the 56GiB guard; restored-service cold admission began at50.05GiB and completed at28.00GiB available.
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
upstream Orca benchmark result**. Local real inference screening has validated
24 GiB resident allocation and the measured prompt set; permanent tuning, production inference and restored-service acceptance completed on2026-10-05. The configured budget is an upper bound: allocation can be smaller,
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
completed on 2026-10-05. Both immutable shards were downloaded and SHA256-verified,
the compatibility pack and matching MTP runtime were produced, and real inference
subsequently completed the measured screening runs linked below. The token can access
the pinned original Qwen MTP head. Access is resolved. Independently reviewed final activation, shared-endpoint lifecycle UAT, the actual production benchmark and restored-service cold admission all completed; see the dated report for evidence and limitations.

Provisioning accepts `STRATA_HF_TOKEN_FILE`; curl reads a temporary mode-0600
header file, and the MTP helper reads the token file without placing credentials
in command arguments/logs. Its HTTP redirects strip authorization across hosts
or HTTPS downgrades. There is no token in the inference service environment.
After tools/account creation, an administrator can provision with the existing
root-readable agenix token and then normalize ownership:

```sh
sudo env STRATA_ORCA_DATA_DIR=/var/lib/strata-orca STRATA_HF_TOKEN_FILE=/run/agenix/huggingface-token strata-orca-provision --provision
sudo chown -R strata-orca:strata-orca /var/lib/strata-orca
sudo chmod 0770 /var/lib/strata-orca
```

This downloads the immutable IQ3_XXS shards, verifies SHA256, makes the model's
compatibility pack/tokenizer, fetches and verifies the original MTP head,
quantizes its experts to Q2_0, exports the runtime, and installs the pinned
`draft_vocab.bin`. Budget at least 110 GB free disk. The helper does **not** start
services or activate NixOS. A custom data directory can be selected with
`STRATA_ORCA_DATA_DIR`, matching the module's `dataDir` setting.

## Validation, review, and benchmark status

Historical build and non-activating rehearsal completed on 2026-10-05, **before
the subsequently authorized provisioning, activation and real inference tests**:

- Formatting/treefmt, shellcheck, and staged whitespace checks passed.
- `nix flake check --impure` passed on the local aarch64-darwin system (six
  checks; incompatible systems are omitted by that command).
- Strata's CUDA sm_89 binary built successfully with CUDA 12.8.93. All **23
  packing tests** and **139 mock-server tests** passed inside the Nix sandbox.
- Packaged server/packing CLI help and provisioning `--dry-run` passed. No model
  weights were downloaded **during that rehearsal**, and real inference had not yet run.
  Subsequent provisioning and measured inference are documented below.
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
Seventeen benchmark evidence/comparison checks reject failed/truncated streams and stale or
concurrent timing evidence. Output-limit incomplete responses are labeled;
telemetry failures mark a benchmark incomplete. Independent Codex peer review
verified lifecycle, recipe, authentication and benchmark evidence against pinned
upstream sources, independently reran the authentication and benchmark checks, and found no
remaining material code issues after the benchmark corrections.

Earlier 32K deployment on 2026-10-05: authenticated immutable provisioning and measured phased tuning completed. The balanced FP16/32K/prefill 2048/23-worker/T4/suffix0/24GiB configuration was deployed from independently reviewed commit `7985f2c`, closure `/nix/store/hfsq6wnvk23rrl42jm8z9hnf0gi8zn81-nixos-system-hal9000-25.11.20260630.b6018f8`. At that acceptance, the system profile and running generation matched. All 23 encrypted activation inputs and runtime file types/owners/groups/modes passed checks before and after switching; legitimate empty plaintext is allowed and no plaintext was read. The two failed rollout/checker events and successful rollbacks are retained in the dated report.

See [the measured report](benchmarks/orca-20261005.md), full raw artifacts and per-trial summary. Final shared-endpoint lifecycle UAT, actual deployed-configuration benchmark and restored desktop/Mold acceptance completed on2026-10-05. The user authorized deployment after independent Codex review and temporary Mold/graphical-session stop during benchmarking. Original service states must be restored while preserving SSH/access and unrelated services. Read-only inspection found approximately 16GiB ZFS ARC (`c_max = 17179869184`); no ARC mutation was needed. Every cold start retains the 36GiB MemAvailable and GPU admission guards. Temporary test-only service stoppage does not justify increasing the normal resident budget or disabling guards.

The benchmark runner below produced the dated screening artifacts. Use these commands
for reproduction; completed repeated measurements and acceptance are tracked in the report:

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
Actual usage tokens, not character count, establish tested depth. Measured depth
now includes 31176 input tokens at 32K and 59469 at 64K, each retrieved exactly
twice; see the dated report. A 700-record prompt can exceed 32K after tokenization,
so use the measured 680-record 32K case rather than assuming it fits.

Optional RAM 24/28/32 GiB candidates require startup guards 36/40/44 GiB, respectively.
Skip infeasible budgets rather than lowering the guard. Optional GPU-cache caps
are 75%/50% of **measured auto expert slots** (`--phase gpu-cache --auto-cache-slots N`),
not GiB. Parser-supported KV variants are fp16/int8/q4_0/k8v4. Int8 is the upstream
Orca recipe's starting point; all four now have bounded local screening evidence
and reviewed code/prose/retrieval outputs. Their quality and resource tradeoffs
still require repeated finalist comparison before choosing a permanent setting.

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
retain zero-compute-client startup. HAL9000 explicitly allows executable
basenames `walker` (observed 268 MiB), `chrome` (120 MiB), `mpv` (469 MiB) and
`swayosd-server` (12 MiB), with an **aggregate 1024 MiB limit** across all
allowed compute PIDs and an actual **20,480 MiB free-VRAM floor** on GPU0. Unknown
compute names, other LLM servers, and Mold/Python compute processes are refused
regardless of current utilization. Missing/N/A PID or memory measurements fail
closed. Graphics allocations are covered by the measured free-VRAM floor.
Names are matched on the executable of the reported command line, and
llama-swap runs with `ProtectProc=default` so nvidia-smi can resolve other
users' process names; under `ProtectProc=invisible` every client reports
`[Not Found]` and the guard refuses all desktop activity.

Native `--vram-reserve-mib 2048` holds two GiB out of auto expert-cache sizing after
initial model/session allocations and prevents the pinned engine from automatically
reducing the reserve toward 300 MiB. Later MTP/verification/driver allocations mean
this is not a guaranteed two GiB of free VRAM while loaded. The measured native
startup reported 1750 MiB free; representative screens peaked near 22482 MiB used
on the 24564 MiB NVML-reported GPU. This is a configured sizing policy, not proof
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

### Hot request-only PCIe screening

Use `benchmark-strata-orca.py --keep-loaded --pcie-fraction 0.55 --workloads code,prose,context_varied_short --trials 2 --output RESULT.json` only after a candidate is already loaded. This mode never unloads it and requires the exact idle model, matching configured native context, and its current request counter before each request. Existing counter, timestamp, native-phase and completion checks still reject unrelated requests or stale timings. Prefix reuse is measured separately; a hot engine does not imply a fresh prompt. No startup/allocation evidence is collected by a hot run, so retain its candidate's preceding cold artifact.

Screen `0.35`, `0.55`, and `0.75` in a balanced repeated order. Artifacts record `request_tuning` separately from generation controls and deployed native arguments. The comparison helper shows the override without splitting otherwise identical prompt/control groups. API payload `strata_tune.pcie_frac` is supported by pinned upstream `serve/server.py:693–699`; `Service.run` passes the same sampling dictionary through every reasoning-budget continuation (`server.py:2300–2303`), so both native phases receive it. Native parsing clamps each request's value to 0–1 (`src/program/generate.cpp:6257–6280`); the runner rejects nonfinite/out-of-range input. The production startup setting is the supported native flag `--pcie-frac F` (`generate.cpp:1404`), not a new environment variable. An absent flag probes PCIe bandwidth and selects the native default `0.55 * min(1, GB/s / 20)` (`generate.cpp:2038–2052`). Request overrides do not persist after that request. Judge throughput and PCIe share together: the displayed GPU cache hit rate excludes offloaded experts and can rise without an actual speed gain.

### Declarative tuning controls

`services.strata-orca` exposes `contextTokens` (32768), `prefillTokens` (512), `kvType` (`int8`; also `fp16`, `q4_0`, `k8v4`), `specWindow` (4; 2–8), `mtpMaxT` (0 means the verification window), `suffixDraft` (3; 0 disables lookup), and `mtpWindowTokens` (32768). The generated MTP context is the minimum of its window and `contextTokens`. Window T allows at most T−1 MTP drafts; this native model requires a loaded MTP runtime, so verification window 1/true MTP-off is unavailable. `mtpMaxT = 1` is a supported loaded-MTP control with zero draft proposals; it differs from omitting the MTP runtime. Suffix lookup can extend the verification window upstream; record both settings when comparing results.

`poolWorkers = null` preserves upstream automatic sizing; positive integers request a fixed count. `poolAffinity` accepts `auto` (module default), `p-cores`, or `all` (upstream default). Auto is an explicit module policy choice. HAL lacks the Linux `cpu_capacity` files used for hybrid detection, so automatic placement does not identify its P cores: the measured `all`/7 combination selects P-core primaries on its observed CPU order. Verify actual affinities when changing hardware or cpusets. `pcieFraction = null` preserves native bandwidth probing; a number from 0 to 1 emits `--pcie-frac`. These options expose reproducible configuration, not a claim that every combination fits available resources. RAM preflight, desktop GPU allowlist, minimum free VRAM and explicit reserve remain enforced. The earlier 32K production benchmark configuration from repeated local trials was FP16 KV, prefill 2048, context32768,23 workers with affinityall, spec4/mtpMaxT4, suffix0, MTP window32768, and native PCIe probing. The RAM24GiB budget/headroom8GiB/guard36GiB and configured2048MiB VRAM reserve remain unchanged. Exact production deployment and restored-state acceptance completed; all measured candidates are retained in the dated benchmark report.

Evaluate configuration and bounds without activation using `python3 scripts/test-strata-tuning-options.py` and `python3 scripts/test-strata-memory-modes.py`. This also verifies absent nullable flags preserve automatic behavior, the MTP context cap and unchanged resource guard metadata.

### Complete source and activation-input preflight

Use `scripts/stage-nixos-revision.py COMMIT /tmp/nixos-orca-reviewed` to stage the reviewed revision and **all pinned submodules**. A plain `git archive` omits gitlink contents, including encrypted agenix inputs. HAL now rejects missing encrypted source files during its system build; the separate preflight also requires nonempty ciphertext and verifies the actual built closure and activation-script references.

Transfer this immutable snapshot to the same isolated path on HAL. Build with `--no-link` and keep the printed closure path outside the snapshot: a newly created `result` link changes a path-based flake's source and can produce a different closure on reevaluation. Run these target-side checks before switching:

```sh
cd /tmp/nixos-orca-reviewed
nix build --impure --no-link --print-out-paths .#nixosConfigurations.hal9000.config.system.build.toplevel > /tmp/orca-reviewed-closure.txt
python3 scripts/verify-nixos-activation-inputs.py --host hal9000 --closure "$(cat /tmp/orca-reviewed-closure.txt)" --ciphertext-root secrets
"$(cat /tmp/orca-reviewed-closure.txt)/bin/switch-to-configuration" dry-activate
```

Require independent review of the exact source/closure and activation approval. After an authorized switch, repeat the same preflight with `--runtime`; it stats **every configured runtime secret path** for existence, regular file type, configured owner/group and permissions without reading plaintext. Valid empty plaintext is allowed; encrypted source files must remain nonempty. Keep rollback automatic on switch/runtime-preflight failure and check service/API health before declaring success. Encrypted inputs remain in the private pinned submodule; neither plaintext nor ciphertext artifacts belong in the benchmark report.
