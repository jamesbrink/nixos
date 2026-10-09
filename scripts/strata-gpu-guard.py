#!/usr/bin/env python3
"""Fail-closed startup GPU sizing with a bounded, explicit desktop allowlist."""

import argparse
import csv
import json
import subprocess
from pathlib import Path


def validate_gpu(processes, free_mib, allowed, maximum_desktop_mib, minimum_free_mib):
    if free_mib < minimum_free_mib:
        raise ValueError(
            f"Orca needs {minimum_free_mib} MiB free VRAM; found {free_mib}"
        )
    aggregate = 0
    for pid, name, memory in processes:
        # nvidia-smi may report the full command line; match the executable only.
        executable = Path(name.split()[0]).name if name.split() else ""
        if int(pid) <= 0 or executable not in allowed:
            raise ValueError(f"Unapproved GPU compute client: pid={pid}, name={name}")
        used = int(memory)
        if used < 0:
            raise ValueError("Invalid desktop GPU memory measurement")
        aggregate += used
    if aggregate > maximum_desktop_mib:
        raise ValueError(
            f"Desktop compute uses {aggregate} MiB, limit {maximum_desktop_mib}"
        )
    return {"free_vram_mib": free_mib, "allowed_desktop_compute_mib": aggregate}


def check(config, executable):
    def query(fields, kind="gpu"):
        return subprocess.check_output(
            [
                executable,
                "--id=0",
                f"--query-{kind}={fields}",
                "--format=csv,noheader,nounits",
            ],
            text=True,
        ).strip()

    free = int(query("memory.free"))
    rows = list(
        csv.reader(
            query("pid,process_name,used_gpu_memory", "compute-apps").splitlines(),
            skipinitialspace=True,
        )
    )
    return validate_gpu(
        rows,
        free,
        config["allowed_desktop_compute_processes"],
        config["maximum_desktop_compute_mib"],
        config["minimum_free_vram_mib"],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--nvidia-smi", default="/run/current-system/sw/bin/nvidia-smi")
    args = parser.parse_args()
    try:
        print(
            json.dumps(
                check(json.loads(Path(args.config).read_text()), args.nvidia_smi)
            )
        )
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit("GPU startup guard refused: " + str(exc))
