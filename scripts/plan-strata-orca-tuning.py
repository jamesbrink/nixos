#!/usr/bin/env python3
"""Generate phased, reversible tuning candidates; never start services or deploy.

Pass the selected finalist JSON back through --config before the next phase.
Native IQ server requires MTP/spec>=2; an MTP-off candidate is unsupported.
"""

import argparse
import copy
import json
from pathlib import Path


def candidate(base, changes):
    config = copy.deepcopy(base)
    args = config["args"]
    for flag, value in changes.items():
        if flag in args:
            args[args.index(flag) + 1] = str(value)
        else:
            args.extend([flag, str(value)])
    if "--resident-budget-gib" in args:
        budget = float(args[args.index("--resident-budget-gib") + 1])
        config["resident_budget_gib"] = budget
        config["minimum_available_gib"] = budget + config["resident_headroom_gib"] + 4
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="/etc/strata-orca.json")
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--phase",
        choices=["mtp", "suffix", "prefill", "context", "ram", "gpu-cache", "kv"],
        required=True,
    )
    parser.add_argument(
        "--auto-cache-slots",
        type=int,
        help="Measured GPU cache expert slots from baseline startup log",
    )
    args = parser.parse_args()
    base = json.loads(Path(args.config).read_text())
    if base.get("memory_mode") != "bounded-mmap":
        parser.error("Tuning planner requires the reviewed bounded-mmap baseline")
    plans = {
        "suffix": [
            (f"suffix-{n}", {"--suffix-draft": n, "--mtp-max-t": 0}) for n in (0, 3)
        ],
        "mtp": [
            (
                f"mtp-window-{t}-drafts-at-most-{t - 1}",
                {"--spec": t, "--mtp-max-t": t, "--suffix-draft": 0},
            )
            for t in (2, 3, 4, 6)
        ],
        "prefill": [(f"prefill-{p}", {"--prefill": p}) for p in (512, 1024, 2048)],
        "context": [
            (f"context-{c}", {"--max-context": c, "--mtp-window": min(c, 32768)})
            for c in (16384, 32768, 65536)
        ],
        "ram": [
            (f"budget-{b}-guard-{b + 12}", {"--resident-budget-gib": b})
            for b in (24, 28, 32)
        ],
        "kv": [(f"kv-{kv}", {"--kv": kv}) for kv in ("int8", "fp16", "k8v4", "q4_0")],
    }
    if args.phase == "gpu-cache":
        if not args.auto_cache_slots or args.auto_cache_slots < 4:
            parser.error("gpu-cache phase requires measured --auto-cache-slots>=4")
        plans["gpu-cache"] = [("gpu-cache-auto", {"--expert-cache": "auto"})] + [
            (
                f"gpu-cache-{fraction}pct",
                {"--expert-cache": int(args.auto_cache_slots * fraction / 100)},
            )
            for fraction in (75, 50)
        ]
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    files = []
    for name, changes in plans[args.phase]:
        path = output / (name + ".json")
        path.write_text(json.dumps(candidate(base, changes), indent=2) + "\n")
        files.append(str(path))
    (output / "manifest.json").write_text(
        json.dumps(
            {
                "phase": args.phase,
                "source_config": args.config,
                "candidates": files,
                "mutations_performed": False,
                "mtp_off": "unsupported by pinned native IQ server",
                "screening": "one code+prose+long trial per candidate; repeat finalists3 times",
                "kv_warning": "non-int8 variants require output-quality comparison, not throughput alone",
            },
            indent=2,
        )
        + "\n"
    )
    print(json.dumps(files, indent=2))


if __name__ == "__main__":
    main()
