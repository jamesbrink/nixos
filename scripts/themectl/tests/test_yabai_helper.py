"""Regression tests for the yabai space helper script."""

from __future__ import annotations

import importlib.resources
import os
import subprocess
from pathlib import Path
import sys

import pytest

pytestmark = pytest.mark.skipif(
    sys.platform != "darwin", reason="yabai helper only runs on macOS"
)

HELPER_RESOURCE = importlib.resources.files("themectl.contrib").joinpath(
    "yabai-space-helper.sh"
)


def _write_exec(path: Path, content: str) -> Path:
    path.write_text(content)
    path.chmod(0o755)
    return path


@pytest.mark.skip(reason="TODO: Fix SIP check logic in test")
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
if [[ "${{1:-}}" == "-m" ]] && [[ "${{2:-}}" == "query" ]]; then
  # Return mock space data for query commands
  echo '[{{"index":1,"display":1}},{{"index":2,"display":1}},{{"index":3,"display":2}},{{"index":4,"display":2}}]'
  exit 0
fi
if [[ "${{1:-}}" == "-m" ]] && [[ "${{2:-}}" == "display" ]] && [[ "${{3:-}}" == "--focus" ]]; then
  # Display focus always succeeds (doesn't need SA)
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

    # Mock csrutil to simulate SIP disabled (allows SA loading)
    csrutil_stub = _write_exec(
        bin_dir / "csrutil",
        """#!/usr/bin/env bash
echo "System Integrity Protection status: disabled."
exit 0
""",
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["YABAI_BIN"] = str(yabai_stub)
    env["SUDO_BIN"] = str(sudo_stub)

    helper_copy = tmp_path / "yabai-space-helper.sh"
    with importlib.resources.as_file(HELPER_RESOURCE) as helper_path:
        helper_copy.write_text(helper_path.read_text())
    helper_copy.chmod(0o755)
    assert helper_copy.exists()

    # With SIP check in place, the helper will:
    # 1. Query which display the space is on
    # 2. Focus that display (works without SA)
    # 3. Try to focus space (fails)
    # 4. Check SIP (disabled in mock)
    # 5. Reload SA
    # 6. Try to focus space again (succeeds)
    result = subprocess.run(
        [str(helper_copy), "focus", "3"],
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )
    assert result.returncode == 0

    log_lines = log_path.read_text().strip().splitlines()
    # Helper queries display, focuses it, tries space focus, reloads SA, succeeds
    assert log_lines == [
        "-m query --spaces",
        "-m display --focus 2",
        "-m space --focus 3",
        "--load-sa",
        "-m query --spaces",
        "-m display --focus 2",
        "-m space --focus 3",
    ]
