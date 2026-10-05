#!/usr/bin/env python3
"""Offline benchmark evidence checks, including stale/failed-stream regressions."""

import argparse
import copy
from types import SimpleNamespace
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

    def test_reasoning_wrap_two_native_phases(self):
        log = "strata serve: prompt 72 tokens = 0 reused + 72 read in 2805 ms (25.7 tok/s), 65 generated in 2632 ms (24.7 tok/s), drafts accepted 39 of 50, 1 checkpoints\nstrata serve: prompt 154 tokens = 136 reused + 18 read in 548 ms (32.9 tok/s), 191 generated in 18389 ms (10.4 tok/s), drafts accepted 134 of 156, 1 checkpoints"
        phases = benchmark.native_phases(log)
        record = {
            "terminal_type": "response.completed",
            "response": {
                "status": "completed",
                "usage": {"input_tokens": 72, "output_tokens": 273},
            },
            "native_phases": phases,
        }
        after = copy.deepcopy(self.after)
        after["last_timings"].update(
            cache_n=136, prompt_n=0, predicted_n=273, predicted_ms=18389.1
        )
        benchmark.validate_trial(record, self.before, after, 100.5)
        accounting = record["native_accounting"]
        self.assertEqual(accounting["native_generated_tokens_all_phases"], 256)
        self.assertEqual(accounting["initial_cached_input_tokens"], 0)
        self.assertEqual(accounting["api_minus_native_output_tokens"], 17)
        self.assertAlmostEqual(
            accounting["native_all_phases_tokens_s"], 256 / 21.021, places=6
        )
        cancelled = benchmark.native_phases(
            log.replace("72 read in", "72 of 72 read in")
        )
        self.assertEqual(cancelled[0]["requested_fresh_prompt_tokens"], 72)
        self.assertAlmostEqual(
            accounting["last_phase_native_tokens_s"], 191 / 18.389, places=6
        )
        after["last_timings"]["cache_n"] = 135
        with self.assertRaises(RuntimeError):
            benchmark.validate_trial(record, self.before, after, 100.5)

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


class HotRequestTests(unittest.TestCase):
    def test_hot_policy_never_unloads(self):
        for policy in ("once", "per-workload"):
            args = SimpleNamespace(keep_loaded=True, cold_policy=policy)
            self.assertFalse(benchmark.cold_workload(args, 0))
            self.assertFalse(benchmark.cold_workload(args, 1))
        args = SimpleNamespace(keep_loaded=False, cold_policy="once")
        self.assertTrue(benchmark.cold_workload(args, 0))
        self.assertFalse(benchmark.cold_workload(args, 1))

    def test_requires_loaded_idle_exact_model_and_counter(self):
        status = {
            "loaded": True,
            "model": benchmark.MODEL,
            "activity": {"requests": 0, "in_flight": 0},
        }
        benchmark.require_loaded(status)
        status["context"] = {"native": 32768}
        benchmark.require_loaded(status, 32768)
        with self.assertRaises(RuntimeError):
            benchmark.require_loaded(status, 65536)
        for field, value in (("loaded", False), ("model", "another-model")):
            wrong = copy.deepcopy(status)
            wrong[field] = value
            with self.assertRaises(RuntimeError):
                benchmark.require_loaded(wrong)
        for field, value in (
            ("requests", None),
            ("requests", True),
            ("requests", -1),
            ("in_flight", 1),
        ):
            wrong = copy.deepcopy(status)
            wrong["activity"][field] = value
            with self.assertRaises(RuntimeError):
                benchmark.require_loaded(wrong)

    def test_pcie_payload_preserves_reasoning_budget(self):
        for fraction in (0, 0.35, 0.55, 0.75, 1):
            tuning = {"pcie_frac": benchmark.pcie_fraction(str(fraction))}
            payload = benchmark.request_payload("code", tuning)
            self.assertEqual(payload["strata_tune"], tuning)
            self.assertEqual(payload["reasoning_budget_tokens"], 64)
            self.assertEqual(payload["model"], benchmark.MODEL)
            self.assertEqual(payload["max_output_tokens"], 384)
            self.assertIsNot(payload["strata_tune"], tuning)
        self.assertNotIn("strata_tune", benchmark.request_payload("code", {}))
        for value in ("-0.1", "1.1", "nan", "inf", "-inf"):
            with self.assertRaises(argparse.ArgumentTypeError):
                benchmark.pcie_fraction(value)


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
