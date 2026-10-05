#!/usr/bin/env python3
"""Evaluate actual HAL module in both memory modes without building/activating."""

import json
import subprocess

expression = r"""
let
  base = (builtins.getFlake (toString ./.)).nixosConfigurations.hal9000;
  resident = base.extendModules {
    modules = [ ({ lib, ... }: { services.strata-orca.memoryMode = lib.mkForce "resident"; }) ];
  };
  json = host: builtins.fromJSON (builtins.unsafeDiscardStringContext host.config.environment.etc."strata-orca.json".source.text);
in { bounded = json base; resident = json resident; }
"""
result = json.loads(
    subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expression], text=True
    )
)
for mode, config in result.items():
    args = config["args"]
    assert config["model_name"] == "orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs"
    assert config["host"] == "127.0.0.1" and config["port"] == 8081
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
