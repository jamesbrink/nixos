#!/usr/bin/env python3
"""Offline benchmark evidence checks, including stale/failed-stream regressions."""

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "benchmark", Path(__file__).with_name("benchmark-strata-orca.py")
)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.record = {
            "terminal_type": "response.completed",
            "response": {
                "status": "completed",
                "usage": {"input_tokens": 100, "output_tokens": 20},
            },
        }
        self.before = {"activity": {"requests": 3}}
        self.after = {
            "model": benchmark.MODEL,
            "activity": {"requests": 4, "in_flight": 0, "last_request_at": 101},
            "last_timings": {
                "at": 101,
                "predicted_n": 20,
                "prompt_n": 60,
                "cache_n": 40,
            },
        }

    def test_completed_current_request(self):
        benchmark.validate_trial(self.record, self.before, self.after, 100.5)
        self.assertTrue(self.record["valid_measurement"])

    def test_explicit_output_limit(self):
        self.record["terminal_type"] = "response.incomplete"
        self.record["response"].update(
            status="incomplete", incomplete_details={"reason": "max_output_tokens"}
        )
        benchmark.validate_trial(self.record, self.before, self.after, 100.5)
        self.assertTrue(self.record["completion_limit_reached"])

    def test_failed_or_missing_terminal(self):
        for terminal in (None, "response.failed"):
            with self.subTest(terminal=terminal):
                record = copy.deepcopy(self.record)
                record["terminal_type"] = terminal
                with self.assertRaises(RuntimeError):
                    benchmark.validate_trial(record, self.before, self.after, 100.5)
                self.assertNotIn("valid_measurement", record)

    def test_stale_or_concurrent_evidence(self):
        mutations = [
            lambda s: s["activity"].update(requests=3),
            lambda s: s["activity"].update(requests=5),
            lambda s: s["activity"].update(in_flight=1),
            lambda s: s["last_timings"].update(at=99),
            lambda s: s["last_timings"].update(predicted_n=19),
            lambda s: s["last_timings"].update(cache_n=0),
        ]
        for mutate in mutations:
            after = copy.deepcopy(self.after)
            mutate(after)
            with self.assertRaises(RuntimeError):
                benchmark.validate_trial(self.record, self.before, after, 100.5)


class MemoryConfigurationTests(unittest.TestCase):
    def test_deployed_modes_and_mismatch(self):
        for bounded in (False, True):
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / "config.json"
                config = {
                    "args": ["--mmap-experts", "--resident-budget-gib", "24"]
                    if bounded
                    else [],
                    "memory_mode": "bounded-mmap" if bounded else "resident",
                    "resident_budget_gib": 24 if bounded else None,
                    "log": "/tmp/strata.log",
                    "port": 18081,
                }
                path.write_text(json.dumps(config))
                self.assertEqual(
                    benchmark.runtime_configuration(path)["mode"], config["memory_mode"]
                )
                config["memory_mode"] = "wrong"
                path.write_text(json.dumps(config))
                with self.assertRaises(RuntimeError):
                    benchmark.runtime_configuration(path)

    def test_resident_arena_evidence(self):
        result = benchmark.allocation_evidence(
            "strata generate: expert arena: page-locked\nstrata generate: loaded 49.80 GiB at 2.20 GiB/s",
            "resident",
        )
        self.assertEqual(result["actual_expert_resident_gib"], 49.8)
        with self.assertRaises(RuntimeError):
            benchmark.allocation_evidence(
                "strata generate: resident RAM mode: 24.00 GiB of experts in RAM",
                "resident",
            )
        with self.assertRaises(RuntimeError):
            benchmark.allocation_evidence(
                "strata generate: expert arena: page-locked\nstrata generate: loaded 49.80 GiB at 2.20 GiB/s",
                "bounded-mmap",
            )

    def test_measured_allocation_and_fallback(self):
        allocation = benchmark.allocation_evidence(
            "strata generate: resident RAM mode: 23.72 GiB of experts in RAM (pageable), 100 in the GPU cache"
        )
        self.assertEqual(allocation["actual_expert_resident_gib"], 23.72)
        fallback = benchmark.allocation_evidence(
            "strata generate: WARNING: the RAM budget (--resident-budget-gib) cannot be kept (out of memory); every expert is read from model files"
        )
        self.assertEqual(fallback["actual_expert_resident_gib"], 0)
        self.assertTrue(fallback["fallback_warnings"])
        with self.assertRaises(RuntimeError):
            benchmark.allocation_evidence("strata started without allocation evidence")


class TuningPlanTests(unittest.TestCase):
    def test_budget_guard_and_mtp_window(self):
        plan_spec = importlib.util.spec_from_file_location(
            "planner", Path(__file__).with_name("plan-strata-orca-tuning.py")
        )
        planner = importlib.util.module_from_spec(plan_spec)
        plan_spec.loader.exec_module(planner)
        base = {
            "args": ["--mmap-experts", "--resident-budget-gib", "24", "--spec", "4"],
            "resident_headroom_gib": 8,
        }
        result = planner.candidate(
            base, {"--resident-budget-gib": 28, "--spec": 2, "--suffix-draft": 0}
        )
        self.assertEqual(result["minimum_available_gib"], 40)
        self.assertEqual(result["resident_budget_gib"], 28)
        self.assertEqual(result["args"][result["args"].index("--spec") + 1], "2")
        self.assertEqual(base["args"][2], "24")


if __name__ == "__main__":
    unittest.main()
