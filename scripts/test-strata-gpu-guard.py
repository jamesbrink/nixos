#!/usr/bin/env python3
"""Representative desktop coexistence and unknown-engine rejection evidence."""

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "guard", Path(__file__).with_name("strata-gpu-guard.py")
)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class GuardTests(unittest.TestCase):
    def validate(self, rows, free=23000, allowed=("walker",)):
        return guard.validate_gpu(rows, free, allowed, 512, 20480)

    def test_small_desktop_allowed(self):
        result = self.validate([("123", "/nix/store/desktop/bin/walker", "268")])
        self.assertEqual(result["allowed_desktop_compute_mib"], 268)

    def test_command_line_name_matches_executable(self):
        chrome = (
            "/nix/store/x-google-chrome/share/google/chrome/chrome --type=gpu-process"
            " --render-node-override=/dev/dri/renderD128 --enable-crash-reporter=?"
        )
        self.validate([("123", chrome, "120")], allowed=("chrome",))
        with self.assertRaises(ValueError):
            self.validate([("123", chrome, "120")], allowed=("renderD128",))
        with self.assertRaises(ValueError):
            self.validate([("123", "", "120")])

    def test_empty_default_is_strict(self):
        self.validate([])
        with self.assertRaises(ValueError):
            self.validate([("123", "walker", "268")], allowed=())

    def test_unknown_compute_or_engine_refused(self):
        for name in (
            "python3",
            "mold",
            "llama-server",
            "ollama",
            "strata",
            "walker-other",
        ):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.validate([("456", name, "1")])

    def test_aggregate_and_free_floor(self):
        self.validate([("1", "walker", "256"), ("2", "walker", "256")], free=20480)
        with self.assertRaises(ValueError):
            self.validate([("1", "walker", "268"), ("2", "walker", "268")])
        with self.assertRaises(ValueError):
            self.validate([], free=20479)

    def test_unknown_measurement_or_pid_refused(self):
        for pid, memory in (("0", "1"), ("N/A", "1"), ("1", "N/A"), ("1", "-1")):
            with self.subTest(pid=pid, memory=memory), self.assertRaises(ValueError):
                self.validate([(pid, "walker", memory)])


if __name__ == "__main__":
    unittest.main()
