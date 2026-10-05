#!/usr/bin/env python3
"""Bounded real benchmark; run on HAL9000 only after reviewed deployment.

python benchmark-strata-orca.py --output docs/benchmarks/orca-YYYYMMDD.json
Uses the shared endpoint for requests; loopback backend status supplies engine timings.
"""

import argparse
import datetime
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
        or timings.get("prompt_n", -1) + timings.get("cache_n", -1)
        != usage.get("input_tokens")
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
    config = json.loads(Path(path).read_text())
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
    log_path = Path(runtime_config["log"])
    report = {
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
        "trials": [],
        "samples": [],
        "notes": [
            "One sequence, no concurrency throughput claim.",
            "Cold engine starts do not imply a cold OS/ZFS disk cache.",
            "First token may be reasoning; answer latency is measured separately.",
            "Engine decode rates include generated reasoning tokens.",
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
                if record["cold_engine"]:
                    with log_path.open("rb") as log:
                        if log_path.stat().st_size < log_offset:
                            log_offset = 0
                        log.seek(log_offset)
                        raw_log = log.read(1048577)
                    if len(raw_log) > 1048576:
                        raise RuntimeError(
                            "Startup allocation log exceeded evidence limit"
                        )
                    record["runtime_allocation_log"] = raw_log.decode(errors="replace")
                    record["runtime_allocation"] = allocation_evidence(
                        record["runtime_allocation_log"], runtime_config["mode"]
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
        report["decode_summary_by_workload_tokens_s"] = {}
        for workload in prompts:
            rates = [
                (t.get("engine_timings") or {}).get("predicted_per_second")
                for t in report["trials"]
                if t["workload"] == workload and t.get("valid_measurement")
            ]
            rates = [rate for rate in rates if rate is not None]
            report["decode_summary_by_workload_tokens_s"][workload] = (
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
    parser.add_argument("--backend", default="http://127.0.0.1:8081")
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
