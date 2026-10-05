#!/usr/bin/env python3
"""Bounded real benchmark; run on HAL9000 only after reviewed deployment.

python benchmark-strata-orca.py --output docs/benchmarks/orca-YYYYMMDD.json
Uses the shared endpoint for requests; loopback backend status supplies engine timings.
"""

import argparse
import datetime
import hashlib
import json
import re
import statistics
import subprocess
import threading
import time
import urllib.request
from pathlib import Path

MODEL = "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs"


def fetch(url, data=None):
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"},
    )
    return urllib.request.urlopen(req, timeout=900)


def native_phases(log):
    pattern = r"strata serve: prompt (\d+) tokens = (\d+) reused \+ (\d+)(?: of (\d+))? read in ([0-9.]+) ms \([0-9.]+ tok/s\), (\d+) generated in ([0-9.]+) ms \([0-9.]+ tok/s\), drafts accepted (\d+) of (\d+)"
    return [
        {
            "prompt_tokens": int(p),
            "cache_n": int(c),
            "fresh_prompt_tokens": int(f),
            "requested_fresh_prompt_tokens": int(requested or f),
            "prompt_ms": float(pm),
            "native_generated_tokens": int(g),
            "decode_ms": float(dm),
            "draft_accepted": int(a),
            "draft_offered": int(d),
        }
        for p, c, f, requested, pm, g, dm, a, d in re.findall(pattern, log)
    ]


def validate_native_accounting(record, usage, timings):
    phases = record.get("native_phases")
    if not phases:
        return timings.get("prompt_n", -1) + timings.get("cache_n", -1) == usage.get(
            "input_tokens"
        )
    first, last = phases[0], phases[-1]
    if (
        first["prompt_tokens"] != usage.get("input_tokens")
        or any(
            p["prompt_tokens"] != p["cache_n"] + p["requested_fresh_prompt_tokens"]
            for p in phases
        )
        or last["cache_n"] != timings.get("cache_n")
        or abs(last["decode_ms"] - timings.get("predicted_ms", -999)) > 2
    ):
        return False
    record["native_accounting"] = {
        "phase_count": len(phases),
        "native_generated_tokens_all_phases": sum(
            p["native_generated_tokens"] for p in phases
        ),
        "native_decode_ms_all_phases": sum(p["decode_ms"] for p in phases),
        "native_prompt_ms_all_phases": sum(p["prompt_ms"] for p in phases),
        "fresh_prompt_tokens_all_phases": sum(p["fresh_prompt_tokens"] for p in phases),
        "initial_cached_input_tokens": first["cache_n"],
        "last_phase_native_generated_tokens": last["native_generated_tokens"],
        "last_phase_native_tokens_s": last["native_generated_tokens"]
        / (last["decode_ms"] / 1000)
        if last["decode_ms"]
        else None,
        "native_all_phases_tokens_s": sum(p["native_generated_tokens"] for p in phases)
        / (sum(p["decode_ms"] for p in phases) / 1000)
        if sum(p["decode_ms"] for p in phases)
        else None,
        "api_minus_native_output_tokens": usage.get("output_tokens", 0)
        - sum(p["native_generated_tokens"] for p in phases),
        "note": "API usage includes injected reasoning-wrap tokens; native counts may include cancellation/drain overrun. Wrapper status exposes final native phase clock/cache with total API predicted_n; these counters must not be divided as though one phase.",
    }
    return True


def validate_trial(record, before, after, began_wall):
    """Fail closed on failed streams, other requests, and stale engine timings."""
    response = record.get("response") or {}
    terminal = record.get("terminal_type")
    status = response.get("status")
    record["status"] = status
    if (
        terminal not in ("response.completed", "response.incomplete")
        or status != terminal.split(".")[1]
    ):
        raise RuntimeError("Missing or failed response terminal: " + str(terminal))
    if status == "incomplete":
        reason = (response.get("incomplete_details") or {}).get("reason")
        if reason != "max_output_tokens":
            raise RuntimeError("Unexpected incomplete response: " + str(reason))
        record["completion_limit_reached"] = True
    usage = response.get("usage") or {}
    timings = after.get("last_timings") or {}
    activity = after.get("activity") or {}
    previous = (before or {}).get("activity") or {}
    expected = previous.get("requests", 0) + 1
    if (
        after.get("model") != MODEL
        or activity.get("requests") != expected
        or activity.get("in_flight") != 0
        or activity.get("last_request_at", 0) < int(began_wall)
        or timings.get("at", 0) < int(began_wall)
        or timings.get("predicted_n") != usage.get("output_tokens")
        or not validate_native_accounting(record, usage, timings)
    ):
        raise RuntimeError("Engine timings cannot be attributed to this request")
    record["engine_timings"] = timings
    record["valid_measurement"] = True


def allocation_evidence(log, mode="bounded-mmap"):
    if mode == "resident":
        arena = re.findall(r"expert arena: ([^\n]+)", log)
        loaded = re.findall(
            r"strata generate: loaded ([0-9.]+) GiB at ([0-9.]+) GiB/s", log
        )
        if not arena or not loaded:
            raise RuntimeError("Resident startup log lacks arena/load evidence")
        return {
            "actual_expert_resident_gib": float(loaded[-1][0]),
            "arena_load_gib_s": float(loaded[-1][1]),
            "arena_description": arena[-1],
            "fallback_warnings": [],
        }
    if mode != "bounded-mmap":
        raise RuntimeError("Unknown allocation mode")
    resident = re.findall(r"resident RAM mode: ([0-9.]+) GiB of experts in RAM", log)
    fallback = [
        line
        for line in log.splitlines()
        if "WARNING:" in line
        and (
            "resident RAM mode does not fit" in line
            or "RAM budget (--resident-budget-gib) cannot be kept" in line
        )
    ]
    if not resident and not fallback:
        raise RuntimeError(
            "Startup log lacks actual resident allocation or explicit mmap fallback"
        )
    return {
        "actual_expert_resident_gib": float(resident[-1]) if resident else 0.0,
        "fallback_warnings": fallback,
        "configured_budget_is_upper_bound": True,
    }


def runtime_configuration(path):
    config_bytes = Path(path).read_bytes()
    config = json.loads(config_bytes)
    native = config["args"]
    bounded = "--mmap-experts" in native
    mode = "bounded-mmap" if bounded else "resident"
    budget = (
        float(native[native.index("--resident-budget-gib") + 1])
        if "--resident-budget-gib" in native
        else None
    )
    if config.get("memory_mode") != mode or (
        bounded and config.get("resident_budget_gib") != budget
    ):
        raise RuntimeError("Deployed memory metadata does not match native arguments")
    return {
        "config_sha256": hashlib.sha256(config_bytes).hexdigest(),
        "backend_port": config["port"],
        "mode": mode,
        "resident_budget_gib": budget,
        "resident_headroom_gib": config.get("resident_headroom_gib"),
        "minimum_available_gib": config.get("minimum_available_gib"),
        "native_args": native,
        "context": int(native[native.index("--max-context") + 1])
        if "--max-context" in native
        else 4096,
        "kv": native[native.index("--kv") + 1] if "--kv" in native else "fp16",
        "prefill": native[native.index("--prefill") + 1]
        if "--prefill" in native
        else None,
        "spec_window": int(native[native.index("--spec") + 1])
        if "--spec" in native
        else 0,
        "expert_cache": native[native.index("--expert-cache") + 1]
        if "--expert-cache" in native
        else None,
        "suffix_draft": int(native[native.index("--suffix-draft") + 1])
        if "--suffix-draft" in native
        else 3,
        "mtp_max_t": int(native[native.index("--mtp-max-t") + 1])
        if "--mtp-max-t" in native
        else 0,
        "mtp_window": int(native[native.index("--mtp-window") + 1])
        if "--mtp-window" in native
        else 32768,
        "spec_min_p": float(native[native.index("--spec-min-p") + 1])
        if "--spec-min-p" in native
        else 0.0,
        "vram_reserve_mib": int(native[native.index("--vram-reserve-mib") + 1])
        if "--vram-reserve-mib" in native
        else 700,
        "gpu_startup_policy": {
            key: config.get(key)
            for key in (
                "allowed_desktop_compute_processes",
                "maximum_desktop_compute_mib",
                "minimum_free_vram_mib",
            )
        },
        "log": config["log"],
    }


def run(args):
    runtime_config = runtime_configuration(args.config)
    if args.backend is None:
        args.backend = "http://127.0.0.1:" + str(runtime_config["backend_port"])
    log_path = Path(runtime_config["log"])
    report = {
        "benchmark_script_sha256": hashlib.sha256(
            Path(__file__).read_bytes()
        ).hexdigest(),
        "runtime_config_sha256": runtime_config["config_sha256"],
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "model": MODEL,
        "api": args.api,
        "backend_status": args.backend,
        "runtime": "Strata 0.1.39 6f32ec070f23ced9f50e704d854d775da52591ab",
        "model_revision": "e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc",
        "quant": "IQ3_XXS",
        "context": runtime_config["context"],
        "kv": runtime_config["kv"],
        "prefill": runtime_config["prefill"],
        "spec": runtime_config["spec_window"],
        "memory_configuration": runtime_config,
        "system": str(Path("/run/current-system").resolve()),
        "cold_policy": args.cold_policy,
        "generation_controls": {
            "max_output_tokens": 384,
            "reasoning_budget_tokens": 64,
            "temperature": 0,
        },
        "trials": [],
        "samples": [],
        "notes": [
            "One sequence, no concurrency throughput claim.",
            "Cold engine starts do not imply a cold OS/ZFS disk cache.",
            "First token may be reasoning; answer latency is measured separately.",
            "Native phase rates exclude injected reasoning wrap; last-phase rate may cover only post-wrap output. API output counts include injected tokens.",
            "Warm engine does not imply warm prefix; cache_n records actual prefix reuse.",
        ],
    }
    stop = threading.Event()
    start = time.monotonic()
    active_trial = [None, None]

    def sample_inner():
        while not stop.is_set():
            mem = {}
            for line in Path("/proc/meminfo").read_text().splitlines():
                key, value = line.split(":", 1)
                if key in ("MemTotal", "MemAvailable", "SwapFree"):
                    mem[key + "_kib"] = int(value.strip().split()[0])
            record, began = active_trial
            if (
                record is not None
                and record["cold_engine"]
                and record.get("engine_ready_s") is None
            ):
                try:
                    with urllib.request.urlopen(
                        args.backend + "/health", timeout=0.3
                    ) as response:
                        if response.status == 200:
                            record["engine_ready_s"] = time.monotonic() - began
                except OSError:
                    pass
            native_rss = 0
            for proc in Path("/proc").iterdir():
                if not proc.name.isdigit():
                    continue
                try:
                    command = (proc / "cmdline").read_bytes().split(b"\0")[0]
                    if command.endswith(b"/strata"):
                        for line in (proc / "status").read_text().splitlines():
                            if line.startswith("VmRSS:"):
                                native_rss += int(line.split()[1])
                except (OSError, ProcessLookupError):
                    pass
            mem["native_rss_kib"] = native_rss
            gpu = subprocess.check_output(
                [
                    "nvidia-smi",
                    "--query-gpu=memory.used,memory.total,utilization.gpu",
                    "--format=csv,noheader,nounits",
                ],
                text=True,
            ).strip()
            report["samples"].append(
                {
                    "elapsed_s": time.monotonic() - start,
                    **mem,
                    "gpu_csv_mib_percent": gpu,
                }
            )
            stop.wait(0.5)

    def sample():
        try:
            sample_inner()
        except Exception as exc:
            report["telemetry_error"] = type(exc).__name__ + ": " + str(exc)

    expected = {}
    prompts = {
        "code": "Write a correct Python function that merges two sorted integer lists in linear time. Include two short tests.",
        "prose": "Explain how a seed grows into a plant to a curious ten-year-old in three clear paragraphs.",
    }
    for label, count in [
        ("context_varied_short", 90),
        ("context_varied_long", args.long_records),
    ]:
        facts = {
            f"entry_{i:05d}": f"code_{(i * 7919 + 104729) % 999983:06d}_{i:04x}"
            for i in range(count)
        }
        lines = [
            f"Record {key}: unique_code={value}; owner=team_{(i * 17) % 101}; cycle={2000 + i}; priority={(i * 13) % 97}."
            for i, (key, value) in enumerate(facts.items())
        ]
        wanted = [list(facts)[i] for i in (0, count // 4, count // 2, count - 1)]
        expected[label] = {key: facts[key] for key in wanted}
        prompts[label] = (
            "\n".join(lines)
            + "\nReturn ONLY a JSON object mapping each requested record ID to its exact unique_code. Requested IDs: "
            + ", ".join(wanted)
        )
    if args.workloads:
        chosen = args.workloads.split(",")
        if any(label not in prompts for label in chosen):
            raise ValueError("Unknown workload selection")
        prompts = {label: prompts[label] for label in chosen}
    # Persist even a failed trial: never replace a failure with invented measurements.
    thread = threading.Thread(target=sample, daemon=True)
    thread.start()
    try:
        for workload_index, (label, prompt) in enumerate(prompts.items()):
            cold_workload = args.cold_policy == "per-workload" or workload_index == 0
            if cold_workload:
                with fetch(args.api + "/api/models/unload/" + MODEL, {}) as response:
                    response.read()
            for trial in range(args.trials):
                record = {
                    "workload": label,
                    "trial": trial + 1,
                    "cold_engine": trial == 0 and cold_workload,
                    "prompt_chars": len(prompt),
                    "prompt": prompt,
                    "first_token_s": None,
                    "first_answer_s": None,
                    "output_text": "",
                    "reasoning_text": "",
                }
                report["trials"].append(record)
                log_offset = log_path.stat().st_size if log_path.exists() else 0
                before = None
                if not record["cold_engine"]:
                    with fetch(args.backend + "/v1/status") as response:
                        before = json.load(response)
                began_wall = time.time()
                began = time.monotonic()
                active_trial[:] = [record, began]
                payload = {
                    "model": MODEL,
                    "input": prompt,
                    "stream": True,
                    "temperature": 0,
                    "max_output_tokens": 384,
                    "reasoning_budget_tokens": 64,
                }
                with fetch(args.api + "/v1/responses", payload) as response:
                    for raw in response:
                        if not raw.startswith(b"data: "):
                            continue
                        event = json.loads(raw[6:])
                        kind = event.get("type", "")
                        if kind in (
                            "response.output_text.delta",
                            "response.reasoning_text.delta",
                        ):
                            record["first_token_s"] = (
                                record["first_token_s"] or time.monotonic() - began
                            )
                            if kind == "response.output_text.delta":
                                record["first_answer_s"] = (
                                    record["first_answer_s"] or time.monotonic() - began
                                )
                                record["output_text"] += event.get("delta", "")
                            else:
                                record["reasoning_text"] += event.get("delta", "")
                        if kind in (
                            "response.completed",
                            "response.incomplete",
                            "response.failed",
                        ):
                            record["terminal_type"] = kind
                            record["response"] = event.get("response")
                record["wall_s"] = time.monotonic() - began
                active_trial[:] = [None, None]
                with fetch(args.backend + "/v1/status") as response:
                    after = json.load(response)
                record["status_before"] = before
                record["status_after"] = after
                with log_path.open("rb") as log:
                    size = log_path.stat().st_size
                    if record["cold_engine"]:
                        log.seek(max(0, size - 1048576))
                        raw_log = log.read()
                        marker = raw_log.rfind(b"strata generate: native pack:")
                        if marker < 0:
                            raise RuntimeError(
                                "Cold log lacks a current native-start marker"
                            )
                        raw_log = raw_log[marker:]
                    else:
                        if size < log_offset:
                            raise RuntimeError("Warm native log unexpectedly truncated")
                        log.seek(log_offset)
                        raw_log = log.read(1048577)
                if len(raw_log) > 1048576:
                    raise RuntimeError("Request native log exceeded evidence limit")
                request_log = raw_log.decode(errors="replace")
                record["native_request_log"] = request_log
                record["native_phases"] = native_phases(request_log)
                if not record["native_phases"]:
                    raise RuntimeError("Request log lacks native phase accounting")
                if record["cold_engine"]:
                    record["runtime_allocation_log"] = request_log
                    record["runtime_allocation"] = allocation_evidence(
                        request_log, runtime_config["mode"]
                    )
                validate_trial(record, before, after, began_wall)
                usage = (record.get("response") or {}).get("usage") or {}
                output = usage.get("output_tokens")
                reasoning = (usage.get("output_tokens_details") or {}).get(
                    "reasoning_tokens"
                )
                record["output_tokens"] = output
                record["reasoning_tokens"] = reasoning
                record["answer_tokens"] = (
                    output - reasoning
                    if output is not None and reasoning is not None
                    else None
                )
                if label in expected:
                    record["expected_retrieval"] = expected[label]
                    answer = record["output_text"].strip()
                    answer = (
                        answer.removeprefix("```json")
                        .removeprefix("```")
                        .removesuffix("```")
                        .strip()
                    )
                    try:
                        retrieved = json.loads(answer)
                    except ValueError:
                        retrieved = None
                    record["retrieval_correct"] = retrieved == expected[label]
                record["api_answer_tokens_per_response_wall_s"] = (
                    record["answer_tokens"] / record["wall_s"]
                    if record["answer_tokens"] is not None
                    else None
                )
                record["request_tokens_per_s"] = (
                    output / record["wall_s"] if output is not None else None
                )
                print(
                    json.dumps(
                        {
                            key: record[key]
                            for key in [
                                "workload",
                                "trial",
                                "wall_s",
                                "output_tokens",
                                "reasoning_tokens",
                                "first_token_s",
                            ]
                        }
                    ),
                    flush=True,
                )
    except Exception as exc:
        report["error"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        active_trial[:] = [None, None]
        stop.set()
        thread.join(timeout=3)
        if thread.is_alive():
            report["telemetry_error"] = "Sampling thread did not stop"
        report["benchmark_complete"] = not report.get("error") and not report.get(
            "telemetry_error"
        )
        report["decode_summary_note"] = (
            "Wrapper rates describe the last native phase; reasoning-budget wraps can make this only the post-wrap phase. See native_accounting for all-phase rates and request_tokens_per_s for API wall rate."
        )
        for summary_name, field in [
            (
                "native_all_phases_summary_by_workload_tokens_s",
                "native_all_phases_tokens_s",
            ),
            (
                "last_native_phase_summary_by_workload_tokens_s",
                "last_phase_native_tokens_s",
            ),
        ]:
            report[summary_name] = {}
            for workload in prompts:
                rates = [
                    (t.get("native_accounting") or {}).get(field)
                    for t in report["trials"]
                    if t["workload"] == workload and t.get("valid_measurement")
                ]
                rates = [rate for rate in rates if rate is not None]
                report[summary_name][workload] = (
                    {
                        "median": statistics.median(rates),
                        "min": min(rates),
                        "max": max(rates),
                    }
                    if rates
                    else None
                )
        if report["samples"]:
            report["memory_summary"] = {
                "minimum_available_kib": min(
                    s["MemAvailable_kib"] for s in report["samples"]
                ),
                "peak_native_rss_kib": max(
                    s["native_rss_kib"] for s in report["samples"]
                ),
                "peak_gpu_used_mib": max(
                    float(s["gpu_csv_mib_percent"].split(",")[0])
                    for s in report["samples"]
                ),
            }
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://127.0.0.1:8080")
    parser.add_argument(
        "--backend", help="Defaults to the actual runtime-config loopback port"
    )
    parser.add_argument(
        "--cold-policy",
        choices=["per-workload", "once"],
        default="per-workload",
        help="once avoids repeated cold starts during screening",
    )
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument(
        "--long-records",
        type=int,
        default=280,
        help="Identical varied retrieval depth across screening candidates; increase for long-context finalists",
    )
    parser.add_argument(
        "--workloads",
        help="Comma-separated code,prose,context_varied_short,context_varied_long",
    )
    parser.add_argument("--config", default="/etc/strata-orca.json")
    parser.add_argument("--output", required=True)
    run(parser.parse_args())
