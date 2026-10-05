#!/usr/bin/env python3
"""Offline benchmark evidence checks, including stale/failed-stream regressions."""

import copy
import importlib.util
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


if __name__ == "__main__":
    unittest.main()
