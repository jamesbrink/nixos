#!/usr/bin/env python3
"""Check model isolation and matching tuning in evaluated NixOS configuration."""

import json
import subprocess

expression = r"""
let h = (builtins.getFlake (toString ./.)).nixosConfigurations.hal9000;
    json = name: builtins.fromJSON (builtins.unsafeDiscardStringContext h.config.environment.etc.${name}.source.text);
in { iq3 = json "strata-orca.json"; q4 = json "strata-orca-q4.json";
     models = h.config.services.llama-swap.settings.models;
     writable = h.config.systemd.services.llama-swap.serviceConfig.ReadWritePaths; }
"""
result = json.loads(
    subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expression], text=True
    )
)
old, new = result["iq3"], result["q4"]
assert old["cwd"] == "/var/lib/strata-orca"
assert new["cwd"] == "/var/lib/strata-orca-q4_k_m"
assert old["port"] != new["port"] and new["port"] == 18082
assert new["model_name"].endswith("-q4_k_m")
assert new["tokenizer"] == new["cwd"] + "/pack/tokenizer"
assert new["log"] == new["cwd"] + "/strata.log"
for key in set(old) - {"args", "cwd", "tokenizer", "log", "model_name", "port"}:
    assert old[key] == new[key], key
for i, value in enumerate(old["args"]):
    if i and old["args"][i - 1] in ("--native", "--ple-gguf"):
        assert (
            new["args"][i].startswith(new["cwd"] + "/models/")
            and "Q4_K_M" in new["args"][i]
        )
    elif i and old["args"][i - 1] == "--pack":
        assert new["args"][i] == new["cwd"] + "/pack"
    else:
        assert new["args"][i] == value, (i, value)
assert new["args"][new["args"].index("--max-context") + 1] == "65536"
assert new["args"][new["args"].index("--mtp-window") + 1] == "32768"
assert new["args"][new["args"].index("--mtp") + 1] == old["cwd"] + "/mtp/rt"
assert {old["model_name"], new["model_name"], "bonsai-2-27b", "qwen3.8-27b"} <= result[
    "models"
].keys()
assert old["cwd"] in result["writable"] and new["cwd"] in result["writable"]
assert result["models"][new["model_name"]]["ttl"] == 600
print(
    "Both quantizations registered with isolated runtime paths, shared 64K/MTP tuning and unchanged resource guards"
)
