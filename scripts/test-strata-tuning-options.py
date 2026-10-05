#!/usr/bin/env python3
"""Evaluate generated tuning arguments and option bounds without activation."""

import json
import subprocess

expression = r"""
let
  base = (builtins.getFlake (toString ./.)).nixosConfigurations.hal9000;
  names = [ "contextTokens" "prefillTokens" "kvType" "specWindow" "mtpMaxT" "suffixDraft" "mtpWindowTokens" "poolWorkers" "poolAffinity" "pcieFraction" ];
  options = base.options.services.strata-orca;
  defaults = builtins.listToAttrs (map (name: { inherit name; value = options.${name}.default; }) names);
  host = values: base.extendModules {
    modules = [ ({ lib, ... }: { services.strata-orca = lib.mapAttrs (_: value: lib.mkForce value) values; }) ];
  };
  json = h: builtins.fromJSON (builtins.unsafeDiscardStringContext h.config.environment.etc."strata-orca.json".source.text);
  valid = {
    contextTokens = 65536; prefillTokens = 2048; kvType = "fp16";
    specWindow = 6; mtpMaxT = 4; suffixDraft = 0; mtpWindowTokens = 32768;
    poolWorkers = 7; poolAffinity = "all"; pcieFraction = 0.75;
  };
  small = defaults // { contextTokens = 16384; kvType = "q4_0"; pcieFraction = 0; };
  check = name: value: options.${name}.type.check value;
in {
  inherit defaults;
  baseline = json (host defaults);
  candidate = json (host valid);
  small = json (host small);
  typeChecks = [
    (check "pcieFraction" null) (check "pcieFraction" 0) (check "pcieFraction" 1.0)
    (!(check "pcieFraction" (-0.1))) (!(check "pcieFraction" 1.1))
    (!(check "specWindow" 1)) (!(check "specWindow" 9))
    (!(check "mtpMaxT" (-1))) (!(check "mtpMaxT" 9))
    (!(check "contextTokens" 0)) (!(check "prefillTokens" 0))
    (!(check "poolWorkers" 0)) (check "poolWorkers" null)
    (!(check "poolAffinity" "none")) (check "poolAffinity" "p-cores")
    (!(check "kvType" "q8_0")) (check "kvType" "k8v4")
    (!(check "suffixDraft" (-1))) (!(check "mtpWindowTokens" 0))
  ];
}
"""
result = json.loads(
    subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expression], text=True
    )
)
assert all(result["typeChecks"])
assert result["defaults"] == {
    "contextTokens": 32768,
    "prefillTokens": 512,
    "kvType": "int8",
    "specWindow": 4,
    "mtpMaxT": 0,
    "suffixDraft": 3,
    "mtpWindowTokens": 32768,
    "poolWorkers": None,
    "poolAffinity": "auto",
    "pcieFraction": None,
}


def flags(config):
    args = config["args"]
    return {
        flag: args[index + 1]
        for index, flag in enumerate(args[:-1])
        if flag.startswith("--") and not args[index + 1].startswith("--")
    }


baseline, candidate, small = (result[key] for key in ("baseline", "candidate", "small"))
b = flags(baseline)
assert b["--max-context"] == "32768" and b["--mtp-window"] == "32768"
assert b["--prefill"] == "512" and b["--kv"] == "int8"
assert b["--spec"] == "4" and b["--mtp-max-t"] == "0" and b["--suffix-draft"] == "3"
assert b["--pool-affinity"] == "auto"
assert "--pool-workers" not in b and "--pcie-frac" not in b
c = flags(candidate)
assert c["--max-context"] == "65536" and c["--mtp-window"] == "32768"
assert c["--prefill"] == "2048" and c["--kv"] == "fp16"
assert c["--spec"] == "6" and c["--mtp-max-t"] == "4" and c["--suffix-draft"] == "0"
assert c["--pool-workers"] == "7" and c["--pool-affinity"] == "all"
assert float(c["--pcie-frac"]) == 0.75
s = flags(small)
assert s["--max-context"] == s["--mtp-window"] == "16384"
assert s["--kv"] == "q4_0" and float(s["--pcie-frac"]) == 0
for config in (baseline, candidate, small):
    for key in (
        "memory_mode",
        "resident_budget_gib",
        "resident_headroom_gib",
        "minimum_available_gib",
        "allowed_desktop_compute_processes",
        "maximum_desktop_compute_mib",
        "minimum_free_vram_mib",
        "host",
        "port",
    ):
        assert config[key] == baseline[key], key
    assert flags(config)["--vram-reserve-mib"] == b["--vram-reserve-mib"]
print(
    "Tuning defaults, generated candidates, context cap, bounds and unchanged resource guards passed"
)
