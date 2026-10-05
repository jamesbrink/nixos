#!/usr/bin/env python3
"""Summarize local benchmark artifacts; never run inference or choose a winner.

Compare only identical prompt sets/model/runtime. Quality precedes speed.
Output preserves cold/warm and prefix-cache categories rather than mixing them.
"""

import argparse
import hashlib
import json
import statistics
from pathlib import Path


def distribution(values):
    values = [
        value for value in values if isinstance(value, (int, float)) and value >= 0
    ]
    return (
        {
            "n": len(values),
            "median": statistics.median(values),
            "min": min(values),
            "max": max(values),
        }
        if values
        else None
    )


def summarize(report, filename):
    trials = report.get("trials", [])
    failures = []
    if (
        not report.get("benchmark_complete")
        or report.get("error")
        or report.get("telemetry_error")
    ):
        failures.append("benchmark incomplete/error/telemetry failure")
    if not trials:
        failures.append("no trials")
    for trial in trials:
        if not trial.get("valid_measurement"):
            failures.append("unattributed or failed trial")
        if trial.get("status") != "completed":
            failures.append("truncated/incomplete answer")
        if not trial.get("output_text", "").strip():
            failures.append("missing final answer")
        if trial.get("retrieval_correct") is False:
            failures.append("incorrect retrieval")
        if (trial.get("runtime_allocation") or {}).get("fallback_warnings"):
            failures.append("unexpected resident-allocation fallback")
        if trial.get("cold_engine") and not trial.get("runtime_allocation"):
            failures.append("missing startup allocation evidence")
    retrieval = [trial for trial in trials if "expected_retrieval" in trial]
    if not retrieval:
        failures.append("retrieval not tested")
    elif any(trial.get("retrieval_correct") is not True for trial in retrieval):
        failures.append("retrieval correctness not proved")
    resource_warnings = [
        line
        for trial in trials
        for line in trial.get("native_request_log", "").splitlines()
        if "low: requests may stall" in line.lower()
        or "no progress" in line.lower()
        or "stalled" in line.lower()
        or "out of memory" in line.lower()
        or "cudaerror" in line.lower()
        or ("warning" in line.lower() and "vram" in line.lower())
    ]
    if resource_warnings:
        failures.append("resource warning requires review")
    workload_metrics = {}
    prompt_set = set()
    for trial in trials:
        workload = trial.get("workload", "unknown")
        prompt_set.add(
            (workload, hashlib.sha256(trial.get("prompt", "").encode()).hexdigest())
        )
        if not trial.get("valid_measurement"):
            continue
        timings = trial.get("engine_timings") or {}
        first_phase = (trial.get("native_phases") or [{}])[0]
        fresh = first_phase.get("fresh_prompt_tokens", timings.get("prompt_n"))
        cached = first_phase.get("cache_n", timings.get("cache_n", 0))
        prefix = (
            "fully_cached_prefix"
            if fresh == 0
            else "partial_prefix"
            if cached > 64
            else "fresh_prefix"
        )
        category = (
            "cold_engine" if trial.get("cold_engine") else "warm_engine_" + prefix
        )
        metrics = workload_metrics.setdefault(workload, {}).setdefault(category, [])
        metrics.append(trial)
    summaries = {}
    for workload, categories in workload_metrics.items():
        summaries[workload] = {}
        for category, rows in categories.items():

            def engine(key):
                return distribution(
                    [(row.get("engine_timings") or {}).get(key) for row in rows]
                )

            def direct(key):
                return distribution([row.get(key) for row in rows])

            phases = [phase for row in rows for phase in row.get("native_phases", [])]
            drafts = sum(phase["draft_offered"] for phase in phases)
            accepted = sum(phase["draft_accepted"] for phase in phases)
            summaries[workload][category] = {
                "wall_s": direct("wall_s"),
                "first_answer_s": direct("first_answer_s"),
                "first_token_s": direct("first_token_s"),
                "engine_ready_s": direct("engine_ready_s"),
                "native_final_phase_tokens_s": distribution(
                    [
                        (row.get("native_accounting") or {}).get(
                            "last_phase_native_tokens_s"
                        )
                        for row in rows
                    ]
                ),
                "native_all_phases_tokens_s": distribution(
                    [
                        (row.get("native_accounting") or {}).get(
                            "native_all_phases_tokens_s"
                        )
                        for row in rows
                    ]
                ),
                "wrapper_last_phase_tokens_s": engine("predicted_per_second"),
                "initial_phase_prefill_tokens_s": distribution(
                    [
                        p["fresh_prompt_tokens"] / (p["prompt_ms"] / 1000)
                        if p["fresh_prompt_tokens"] and p["prompt_ms"]
                        else None
                        for row in rows
                        for p in (row.get("native_phases") or [])[:1]
                    ]
                ),
                "input_tokens": distribution(
                    [
                        ((row.get("response") or {}).get("usage") or {}).get(
                            "input_tokens"
                        )
                        for row in rows
                    ]
                ),
                "output_tokens": direct("output_tokens"),
                "answer_tokens": direct("answer_tokens"),
                "reasoning_tokens": direct("reasoning_tokens"),
                "draft_acceptance": accepted / drafts if drafts else None,
            }
    identity = [report.get(key) for key in ("model", "model_revision", "runtime")]
    controls = report.get("generation_controls") or {
        "max_output_tokens": sorted(
            {(t.get("response") or {}).get("max_output_tokens") for t in trials},
            key=str,
        ),
        "temperature": sorted(
            {(t.get("response") or {}).get("temperature") for t in trials}, key=str
        ),
        "reasoning_budget_tokens": "not recorded",
    }
    signature = hashlib.sha256(
        json.dumps([identity, sorted(prompt_set), controls]).encode()
    ).hexdigest()
    allocation = [
        trial["runtime_allocation"]
        for trial in trials
        if trial.get("runtime_allocation")
    ]
    return {
        "file": filename,
        "comparison_group": signature,
        "generation_controls": controls,
        "automatic_quality_gates_pass": not failures,
        "gate_failures": sorted(set(failures)),
        "manual_code_prose_review_required": any(
            trial.get("workload") in ("code", "prose") for trial in trials
        ),
        "resource_warning_lines": resource_warnings,
        "configuration": report.get("memory_configuration"),
        "metrics_by_workload_and_cache_state": summaries,
        "memory_summary": report.get("memory_summary"),
        "allocation_evidence": allocation,
        "fallback_observed": any(item.get("fallback_warnings") for item in allocation),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="+")
    parser.add_argument("--output", help="Optional local comparison JSON")
    args = parser.parse_args()
    comparison = {
        "candidates": [
            summarize(json.loads(Path(path).read_text()), path)
            for path in args.artifacts
        ],
        "ranking_policy": "Quality gates first; compare identical comparison_group and workload/cache state. Prefer repeatably lower answer/wall latency without material workload regressions; decode speed and draft acceptance diagnose performance, not answer quality. Inspect memory/fallback evidence and manually review code/prose before selecting a winner.",
    }
    result = json.dumps(comparison, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(result)
    print(result)
