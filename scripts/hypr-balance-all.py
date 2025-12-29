#!/usr/bin/env python3
"""
Balance all tiled window columns in Hyprland workspace.

This script attempts to equalize the width of all visible columns in the
current workspace. It works best with fresh layouts where windows were
opened in sequence. Complex layouts with nested splits may not fully balance
due to dwindle tree constraints.

Usage:
    python3 hypr-balance-all.py

How it works:
1. Identifies top-row windows as column representatives
2. Calculates target width = (monitor_width - gaps) / num_columns
3. Iteratively resizes columns toward target
4. Detects oscillation and tree constraints, exiting gracefully

Limitations:
- Dwindle layout uses a binary tree; not all configurations can achieve
  equal columns without reorganizing the tree
- Works best with simple column layouts (no nested horizontal splits)
- May leave some columns unbalanced if tree structure prevents it
"""

import json
import subprocess
import time
from dataclasses import dataclass
from collections import deque


@dataclass
class Window:
    address: str
    x: int
    y: int
    width: int
    height: int


def hyprctl(args: list[str]) -> str:
    """Run hyprctl command and return stdout."""
    result = subprocess.run(["hyprctl"] + args, capture_output=True, text=True)
    return result.stdout.strip()


def hyprctl_json(args: list[str]):
    """Run hyprctl with -j flag and parse JSON."""
    return json.loads(hyprctl(args + ["-j"]))


def get_all_tiled(workspace_id: int) -> list[Window]:
    """Get all tiled (non-floating) windows in workspace."""
    return [
        Window(c["address"], c["at"][0], c["at"][1], c["size"][0], c["size"][1])
        for c in hyprctl_json(["clients"])
        if c["workspace"]["id"] == workspace_id and not c["floating"]
    ]


def get_top_row(workspace_id: int) -> list[Window]:
    """Get windows at the topmost Y position, sorted by X."""
    windows = get_all_tiled(workspace_id)
    if not windows:
        return []
    min_y = min(w.y for w in windows)
    top = [w for w in windows if abs(w.y - min_y) <= 50]
    top.sort(key=lambda w: w.x)
    return top


def get_window(workspace_id: int, address: str) -> Window | None:
    """Get current state of a window by address."""
    for c in hyprctl_json(["clients"]):
        if c["address"] == address and c["workspace"]["id"] == workspace_id:
            return Window(c["address"], c["at"][0], c["at"][1], c["size"][0], c["size"][1])
    return None


def try_resize(workspace_id: int, address: str, target: int, step: int = 100) -> bool:
    """
    Attempt to resize a window toward target width.

    The resize direction depends on window position in the layout, so we
    try positive delta first, check if it moved correctly, and if not,
    undo and try negative delta.

    Returns True if resize moved in the correct direction.
    """
    w = get_window(workspace_id, address)
    if not w:
        return False

    current = w.width
    if abs(current - target) < 30:
        return False  # Already close enough

    need_shrink = current > target
    need_grow = current < target

    # Focus window
    hyprctl(["dispatch", "focuswindow", f"address:{address}"])
    time.sleep(0.01)

    # Try positive delta first
    hyprctl(["dispatch", "resizeactive", "--", str(step), "0"])
    time.sleep(0.01)

    w_after = get_window(workspace_id, address)
    if not w_after:
        return False

    grew = w_after.width > current
    shrank = w_after.width < current

    if (need_shrink and shrank) or (need_grow and grew):
        return True  # Correct direction

    if grew or shrank:
        # Wrong direction - undo and try negative
        hyprctl(["dispatch", "resizeactive", "--", str(-step), "0"])
        time.sleep(0.01)

        hyprctl(["dispatch", "resizeactive", "--", str(-step), "0"])
        time.sleep(0.01)

        w_after2 = get_window(workspace_id, address)
        if w_after2:
            grew2 = w_after2.width > current
            shrank2 = w_after2.width < current
            if (need_shrink and shrank2) or (need_grow and grew2):
                return True

    return False


def main():
    workspace_id = hyprctl_json(["activeworkspace"])["id"]
    monitors = hyprctl_json(["monitors"])

    monitor_width = monitors[0]["width"]
    for m in monitors:
        if m.get("activeWorkspace", {}).get("id") == workspace_id:
            monitor_width = m["width"]
            break

    original_focus = hyprctl_json(["activewindow"]).get("address")

    # Configuration
    GAPS = 10
    TOLERANCE = 80
    MAX_ITER = 60
    STEP = 150

    print(f"Monitor: {monitor_width}px | Workspace: {workspace_id}")

    columns = get_top_row(workspace_id)
    n = len(columns)

    if n <= 1:
        print("Need ≥2 columns to balance")
        return

    target = (monitor_width - GAPS * (n + 1)) // n
    col_addresses = [c.address for c in columns]

    print(f"\nColumns: {n} | Target: {target}px")
    print(f"Initial: {[c.width for c in columns]}")

    history: deque[tuple] = deque(maxlen=15)

    for iteration in range(1, MAX_ITER + 1):
        widths = []
        for addr in col_addresses:
            w = get_window(workspace_id, addr)
            widths.append(w.width if w else 0)

        state = tuple(widths)
        max_dev = max(abs(w - target) for w in widths)

        if iteration <= 10 or iteration % 10 == 0:
            print(f"[{iteration:2d}] {widths} max_dev={max_dev}")

        if all(abs(w - target) <= TOLERANCE for w in widths):
            print(f"\n✓ Balanced in {iteration} iterations!")
            break

        if state in history:
            print(f"\n⚠ Oscillation detected")
            break
        history.append(state)

        # Find most deviated column
        best_i = -1
        best_dev = 0
        for i in range(n):
            dev = abs(widths[i] - target)
            if dev > best_dev and dev > TOLERANCE:
                best_dev = dev
                best_i = i

        if best_i < 0:
            break

        # Try to resize
        success = try_resize(workspace_id, col_addresses[best_i], target, STEP)
        if not success:
            # Try next most deviated column
            candidates = sorted(
                [(i, abs(widths[i] - target)) for i in range(n) if i != best_i],
                key=lambda x: -x[1]
            )
            for idx, dev in candidates:
                if dev > TOLERANCE:
                    if try_resize(workspace_id, col_addresses[idx], target, STEP):
                        break

    # Final output
    widths = []
    for addr in col_addresses:
        w = get_window(workspace_id, addr)
        widths.append(w.width if w else 0)

    print(f"\n{'='*50}")
    print(f"Target: {target}")
    print(f"Final:  {widths}")
    max_dev = max(abs(w - target) for w in widths)
    print(f"Max deviation: {max_dev}")

    if all(abs(w - target) <= TOLERANCE for w in widths):
        print("✓ Balanced!")
    else:
        print("⚠ Tree constraints prevented full balance")

    if original_focus:
        hyprctl(["dispatch", "focuswindow", f"address:{original_focus}"])


if __name__ == "__main__":
    main()
