"""Regression tests for the yabai space helper script."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

HELPER = Path(__file__).resolve().parents[1] / "contrib" / "yabai-space-helper.sh"


def _write_exec(path: Path, content: str) -> Path:
    path.write_text(content)
    path.chmod(0o755)
    return path


def test_space_helper_reloads_scripting_addition(tmp_path: Path) -> None:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log_path = tmp_path / "log"
    sa_flag = tmp_path / "sa_loaded"

    yabai_stub = _write_exec(
        bin_dir / "yabai",
        f"""#!/usr/bin/env bash
set -euo pipefail
echo "$@" >> "{log_path}"
if [[ "${{1:-}}" == "--load-sa" ]]; then
  touch "{sa_flag}"
  exit 0
fi
if [[ -f "{sa_flag}" ]]; then
  exit 0
fi
exit 1
""",
    )

    sudo_stub = _write_exec(
        bin_dir / "sudo",
        """#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-n" ]]; then
    shift
fi
exec "$@"
""",
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["YABAI_BIN"] = str(yabai_stub)
    env["SUDO_BIN"] = str(sudo_stub)

    result = subprocess.run(
        [str(HELPER), "focus", "3"],
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )
    assert result.returncode == 0

    log_lines = log_path.read_text().strip().splitlines()
    assert log_lines == [
        "-m space --focus 3",
        "--load-sa",
        "-m space --focus 3",
    ]
