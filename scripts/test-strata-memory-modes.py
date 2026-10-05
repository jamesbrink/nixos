#!/usr/bin/env python3
"""Evaluate actual HAL module in both memory modes without building/activating."""

import argparse
import json
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--check-host", help="Read-only SSH executable check, e.g. root@hal9000"
)
args = parser.parse_args()

expression = r"""
let
  base = (builtins.getFlake (toString ./.)).nixosConfigurations.hal9000;
  resident = base.extendModules {
    modules = [ ({ lib, ... }: { services.strata-orca.memoryMode = lib.mkForce "resident"; }) ];
  };
  json = host: builtins.fromJSON (builtins.unsafeDiscardStringContext host.config.environment.etc."strata-orca.json".source.text);
in { bounded = json base; resident = json resident; defaultAllowlist = base.options.services.strata-orca.allowedDesktopComputeProcesses.default; nvidiaSmi = "${base.config.hardware.nvidia.package.bin}/bin/nvidia-smi"; guardCommand = base.config.services.llama-swap.settings.models."orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs".cmd; }
"""
result = json.loads(
    subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expression], text=True
    )
)
assert result.pop("defaultAllowlist") == []
nvidia_smi = result.pop("nvidiaSmi")
guard_command = result.pop("guardCommand")
if args.check_host:
    subprocess.run(
        ["ssh", args.check_host, "test -x " + shlex.quote(nvidia_smi)], check=True
    )
    launcher = subprocess.check_output(
        ["ssh", args.check_host, "cat " + shlex.quote(shlex.split(guard_command)[0])],
        text=True,
    )
    assert "--nvidia-smi " + nvidia_smi in launcher, (
        "Evaluated launcher uses wrong NVIDIA output"
    )
    listeners = subprocess.check_output(
        ["ssh", args.check_host, "ss -H -ltn " + shlex.quote("sport = :18081")],
        text=True,
    ).strip()
    assert not listeners, "Orca loopback port18081 is already occupied: " + listeners
    print(
        "Verified target port18081 unused and evaluated launcher NVIDIA bin output: "
        + nvidia_smi
    )
for mode, config in result.items():
    args = config["args"]
    assert config["model_name"] == "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs"
    assert config["host"] == "127.0.0.1" and config["port"] == 18081
    assert config["allowed_desktop_compute_processes"] == ["walker"]
    assert config["maximum_desktop_compute_mib"] == 512
    assert config["minimum_free_vram_mib"] == 20480
    assert args[args.index("--vram-reserve-mib") + 1] == "2048"
    if mode == "bounded":
        assert config["memory_mode"] == "bounded-mmap"
        assert args[args.index("--resident-budget-gib") + 1] == "24"
        assert "--mmap-experts" in args
        assert config["resident_headroom_gib"] == 8
        assert config["minimum_available_gib"] == 36
    else:
        assert config["memory_mode"] == "resident"
        assert "--mmap-experts" not in args and "--resident-budget-gib" not in args
        assert config["resident_budget_gib"] is None
        assert config["minimum_available_gib"] == 56
print("HAL bounded-mmap and resident module evaluations passed")
