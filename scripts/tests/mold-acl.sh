#!/usr/bin/env bash
set -euo pipefail
# Run on Linux as root with the rendered mold-acl service script as argument.
python3 - "$1" <<'PY'
import pathlib
import subprocess
import sys
import tempfile

script = pathlib.Path(sys.argv[1]).read_text()
with tempfile.TemporaryDirectory(prefix="mold-acl-regression-") as raw:
    base = pathlib.Path(raw)
    for index, original in enumerate(("/mnt/storage20tb/AI/mold", "/storage-fast/mold")):
        root = base / str(index)
        root.mkdir()
        shared = root / "output"
        shared.mkdir()
        (shared / "media").write_bytes(b"retained media")
        for directory in ("secure", "queue-media"):
            private = root / directory
            private.mkdir(mode=0o700)
            (private / "authority").write_bytes(b"retained authority and grants")
            (private / "authority").chmod(0o600)
        # Reproduce already-corrupted private stores before applying the repair.
        subprocess.run(["setfacl", "-R", "-m", "u:jamesbrink:rwX", str(root)], check=True)
        subprocess.run(["setfacl", "-R", "-d", "-m", "u:jamesbrink:rwx", str(root)], check=True)
        script = script.replace(original, str(root))
    for _ in range(2):
        subprocess.run(["bash", "-e", "-c", script], check=True)
        for root in base.iterdir():
            for directory in ("secure", "queue-media"):
                private = root / directory
                authority = private / "authority"
                assert private.stat().st_mode & 0o777 == 0o700
                assert authority.stat().st_mode & 0o777 == 0o600
                assert authority.read_bytes() == b"retained authority and grants"
                acl = subprocess.check_output(["getfacl", "-cp", str(private)], text=True)
                assert "default:" not in acl and "user:jamesbrink:" not in acl
            acl = subprocess.check_output(["getfacl", "-cp", str(root / "output")], text=True)
            assert "user:jamesbrink:rwx" in acl and "default:user:jamesbrink:rwx" in acl
    print("PASS: repeated production ACL script preserves private authorities and shared media")
PY
