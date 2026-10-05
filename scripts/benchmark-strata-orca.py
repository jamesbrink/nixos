#!/usr/bin/env python3
"""Bounded real benchmark; run on HAL9000 only after reviewed deployment.

python benchmark-strata-orca.py --output docs/benchmarks/orca-YYYYMMDD.json
Uses the shared endpoint for requests; loopback backend status supplies engine timings.
"""

import argparse
import datetime
import json
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


def run(args):
    report = {
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "model": MODEL,
        "api": args.api,
        "backend_status": args.backend,
        "runtime": "Strata 0.1.39 6f32ec070f23ced9f50e704d854d775da52591ab",
        "model_revision": "e43d00f4e2b8b40b89f75e9adeb1045ac34c8acc",
        "quant": "IQ3_XXS",
        "context": 32768,
        "kv": "int8",
        "prefill": 512,
        "spec": 4,
        "resident_mode": "upstream-validated resident arena",
        "system": str(Path("/run/current-system").resolve()),
        "trials": [],
        "samples": [],
        "notes": [
            "One sequence, no concurrency throughput claim.",
            "Cold engine starts do not imply a cold OS/ZFS disk cache.",
            "First token may be reasoning; answer latency is measured separately.",
            "Engine decode rates include generated reasoning tokens.",
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

    prompts = {
        "code": "Write a correct Python function that merges two sorted integer lists in linear time. Include two short tests.",
        "prose": "Explain how a seed grows into a plant to a curious ten-year-old in three clear paragraphs.",
        "context_8k_chars": (
            "Field note: rain supplies water, leaves collect sunlight, and roots take minerals from soil.\n"
            * 90
        )
        + "\nSummarize the field notes in three sentences.",
        "context_64k_chars": (
            "Field note: rain supplies water, leaves collect sunlight, and roots take minerals from soil.\n"
            * 700
        )
        + "\nSummarize the field notes in three sentences.",
    }
    # Persist even a failed trial: never replace a failure with invented measurements.
    thread = threading.Thread(target=sample, daemon=True)
    thread.start()
    try:
        for label, prompt in prompts.items():
            with fetch(args.api + "/api/models/unload/" + MODEL, {}) as response:
                response.read()
            for trial in range(args.trials):
                record = {
                    "workload": label,
                    "trial": trial + 1,
                    "cold_engine": trial == 0,
                    "prompt_chars": len(prompt),
                    "prompt": prompt,
                    "first_token_s": None,
                    "first_answer_s": None,
                    "output_text": "",
                    "reasoning_text": "",
                }
                report["trials"].append(record)
                before = None
                if trial != 0:
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
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument("--output", required=True)
    run(parser.parse_args())
