#!/usr/bin/env python3
"""Temporary llama-swap child launcher for a reviewed tuning JSON; no activation.

Use as the Orca model cmd in an isolated temporary copy of llama-swap's config.
The same endpoint/lifecycle manages it. Does not stop other GPU processes.
"""

import argparse
import json
import os
import subprocess
from pathlib import Path


def require(condition, message):
    if not condition:
        raise SystemExit(message)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("config")
args = parser.parse_args()
config_path = Path(args.config).resolve()
config = json.loads(config_path.read_text())
require(
    config["memory_mode"] == "bounded-mmap",
    "Only bounded tuning candidates are allowed",
)
require(
    config["host"] == "127.0.0.1" and config["port"] == 8081,
    "Candidate must use loopback8081",
)
native = config["args"]
budget = float(native[native.index("--resident-budget-gib") + 1])
headroom = config["resident_headroom_gib"]
require(
    "--mmap-experts" in native and 0 < budget <= 32 and headroom >= 8,
    "Candidate violates reviewed memory bounds",
)
require(
    config["resident_budget_gib"] == budget, "Budget metadata differs from native args"
)
minimum = budget + headroom + 4
require(
    config["minimum_available_gib"] == minimum,
    "Candidate startup guard is inconsistent",
)
available = next(
    int(line.split()[1])
    for line in Path("/proc/meminfo").read_text().splitlines()
    if line.startswith("MemAvailable:")
)
if available < minimum * 1048576:
    raise SystemExit(f"Candidate needs {minimum} GiB available; found {available} KiB")
gpu = subprocess.check_output(
    [
        "/run/current-system/sw/bin/nvidia-smi",
        "--query-compute-apps=pid",
        "--format=csv,noheader",
    ],
    text=True,
).strip()
if gpu:
    raise SystemExit(
        "Refusing candidate while another GPU compute process is resident: " + gpu
    )
for path in (
    Path(config["cwd"]) / "pack/native_experts.txt",
    Path(config["cwd"]) / "mtp/rt/draft_vocab.bin",
):
    require(path.stat().st_size > 0, "Missing packed model data")
os.environ["STRATA_RESIDENT_HEADROOM_GIB"] = str(headroom)
os.environ["LD_LIBRARY_PATH"] = "/run/opengl-driver/lib" + (
    ":" + os.environ["LD_LIBRARY_PATH"] if os.environ.get("LD_LIBRARY_PATH") else ""
)
server = str(Path(config["exe"]).with_name("strata-server"))
# exec preserves llama-swap's group; its stop-before-start guard and forced kill apply.
os.execv(
    server,
    [
        server,
        "--engine",
        "strata",
        "--config",
        str(config_path),
        "--host",
        "127.0.0.1",
        "--port",
        "8081",
    ],
)
