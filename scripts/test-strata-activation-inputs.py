#!/usr/bin/env python3
"""Runtime metadata verification accepts empty secrets and rejects unsafe metadata."""

import grp
import importlib.util
import os
from pathlib import Path
import pwd
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "activation_inputs", Path(__file__).with_name("verify-nixos-activation-inputs.py")
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def rejects(value, message):
    try:
        module.verify_runtime({"fixture": value})
    except ValueError as error:
        assert message in str(error), error
    else:
        raise AssertionError(f"Expected rejection: {message}")


with tempfile.TemporaryDirectory() as temporary:
    path = Path(temporary) / "empty-runtime-secret"
    path.touch(mode=0o600)
    value = {
        "runtime_path": str(path),
        "owner": pwd.getpwuid(os.getuid()).pw_name,
        "group": grp.getgrgid(os.getgid()).gr_name,
        "mode": "0600",
    }
    with patch.object(Path, "read_bytes", side_effect=AssertionError("No plaintext reads")), patch.object(Path, "read_text", side_effect=AssertionError("No plaintext reads")):
        module.verify_runtime({"fixture": value})
        module.verify_runtime({"fixture": value | {"owner": str(os.getuid()), "group": str(os.getgid())}})
    assert path.stat().st_size == 0
    rejects(value | {"runtime_path": str(path.with_name("missing"))}, "Missing runtime")
    rejects(value | {"runtime_path": temporary}, "not a regular file")
    rejects(value | {"mode": "0400"}, "mode differs")
    rejects(value | {"owner": str(os.getuid() + 1)}, "owner differs")
    rejects(value | {"group": str(os.getgid() + 1)}, "group differs")
    with patch.object(module.pwd, "getpwnam", return_value=type("Owner", (), {"pw_uid": os.getuid() + 1})()):
        rejects(value, "owner differs")
    with patch.object(module.grp, "getgrnam", return_value=type("Group", (), {"gr_gid": os.getgid() + 1})()):
        rejects(value, "group differs")
print("Empty plaintext accepted without reads; missing/type/owner/group/mode mismatches rejected")
