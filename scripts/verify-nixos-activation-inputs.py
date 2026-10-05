#!/usr/bin/env python3
"""Fail closed if configured encrypted inputs are absent from source or closure."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def verify(inputs, closure_paths=None, ciphertext_root=None):
    if not inputs:
        raise ValueError("No configured secrets: refusing an empty activation-input inventory")
    manifest = {}
    for name, raw_path in inputs.items():
        path = Path(raw_path)
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"Missing or empty encrypted activation input: {name}")
        if path.suffix != ".age" or path.parts[:3] != ("/", "nix", "store"):
            raise ValueError(f"Activation input must be an encrypted Nix store file: {name}")
        store_root = Path(*path.parts[:4])
        if closure_paths is not None and str(store_root) not in closure_paths:
            raise ValueError(f"Encrypted input source is absent from built closure: {name}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if ciphertext_root is not None:
            relative = path.relative_to(store_root)
            if not relative.parts or relative.parts[0] != "secrets":
                raise ValueError(f"Unexpected encrypted input source layout: {name}")
            original = ciphertext_root.joinpath(*relative.parts[1:])
            if not original.is_file() or hashlib.sha256(original.read_bytes()).hexdigest() != digest:
                raise ValueError(f"Ciphertext differs from pinned source: {name}")
        manifest[name] = {"file": str(path), "ciphertext_sha256": digest}
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flake", type=Path, default=Path.cwd())
    parser.add_argument("--host", required=True)
    parser.add_argument("--closure", type=Path)
    parser.add_argument("--ciphertext-root", type=Path)
    parser.add_argument("--runtime", action="store_true", help="Also stat every configured runtime secret path; never read plaintext")
    args = parser.parse_args()
    expression = (
        "let c=(builtins.getFlake " + json.dumps(str(args.flake.resolve()))
        + ").nixosConfigurations." + json.dumps(args.host)
        + ".config; in builtins.mapAttrs (_: s: { file=toString s.file; runtime_path=s.path; }) c.age.secrets"
    )
    inputs = json.loads(subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--expr", expression], text=True
    ))
    closure_paths = None
    if args.closure:
        closure_paths = set(subprocess.check_output(
            ["nix-store", "--query", "--requisites", str(args.closure.resolve())], text=True
        ).splitlines())
    verify({name: value["file"] for name, value in inputs.items()}, closure_paths, args.ciphertext_root)
    if args.closure:
        activation = (args.closure.resolve() / "activate").read_text()
        references = {
            str(Path(value))
            for value in re.findall(r"/nix/store/[^\s\"']+\.age", activation)
        }
        for name, value in inputs.items():
            if str(Path(value["file"])) not in references:
                raise ValueError(f"Encrypted input not referenced by built activation script: {name}")
    if args.runtime:
        for name, value in inputs.items():
            path = Path(value["runtime_path"])
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"Missing or empty runtime secret: {name}")
        print(f"Verified {len(inputs)} runtime secret paths exist and are nonempty; no plaintext read")
    scope = "source and built closure" if args.closure else "source only; built closure NOT checked"
    print(f"Verified {len(inputs)} nonempty encrypted activation inputs ({scope}); no plaintext read")


if __name__ == "__main__":
    main()
