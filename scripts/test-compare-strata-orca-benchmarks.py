#!/usr/bin/env python3
"""Artifact quality gates and native-phase grouping regression checks."""

import copy
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "compare", Path(__file__).with_name("compare-strata-orca-benchmarks.py")
)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.report = {
            "benchmark_complete": True,
            "model": "Orca",
            "model_revision": "pinned",
            "runtime": "pinned",
            "trials": [
                {
                    "workload": "context_varied_short",
                    "prompt": "distinct facts",
                    "cold_engine": False,
                    "valid_measurement": True,
                    "status": "completed",
                    "output_text": '{"answer":"correct"}',
                    "expected_retrieval": {"answer": "correct"},
                    "retrieval_correct": True,
                    "engine_timings": {
                        "prompt_n": 0,
                        "cache_n": 136,
                        "predicted_per_second": 10.4,
                    },
                    "native_phases": [
                        {
                            "fresh_prompt_tokens": 72,
                            "cache_n": 0,
                            "prompt_ms": 2805,
                            "draft_offered": 50,
                            "draft_accepted": 39,
                        }
                    ],
                    "native_accounting": {
                        "last_phase_native_tokens_s": 10.3866,
                        "native_all_phases_tokens_s": 12.1783,
                    },
                }
            ],
        }

    def test_initial_phase_cache_category_and_rate_labels(self):
        result = compare.summarize(self.report, "fixture")
        self.assertTrue(result["automatic_quality_gates_pass"])
        metrics = result["metrics_by_workload_and_cache_state"]["context_varied_short"][
            "warm_engine_fresh_prefix"
        ]
        self.assertAlmostEqual(metrics["native_all_phases_tokens_s"]["median"], 12.1783)
        self.assertAlmostEqual(
            metrics["initial_phase_prefill_tokens_s"]["median"], 72 / 2.805
        )

    def test_failed_quality_cannot_pass(self):
        for change in (
            {"retrieval_correct": False},
            {"status": "incomplete"},
            {"output_text": ""},
            {"valid_measurement": False},
        ):
            report = copy.deepcopy(self.report)
            report["trials"][0].update(change)
            self.assertFalse(
                compare.summarize(report, "fixture")["automatic_quality_gates_pass"]
            )

    def test_low_vram_warning_is_a_gate(self):
        self.report["trials"][0]["native_request_log"] = (
            "strata serve: 180 MiB of VRAM free with everything loaded - LOW: requests may stall"
        )
        result = compare.summarize(self.report, "fixture")
        self.assertFalse(result["automatic_quality_gates_pass"])
        self.assertTrue(result["resource_warning_lines"])

    def test_prompt_groups_must_match(self):
        first = compare.summarize(self.report, "a")["comparison_group"]
        self.report["trials"][0]["prompt"] = "different facts"
        self.assertNotEqual(
            first, compare.summarize(self.report, "b")["comparison_group"]
        )


if __name__ == "__main__":
    unittest.main()
