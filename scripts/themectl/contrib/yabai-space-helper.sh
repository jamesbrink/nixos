#!/usr/bin/env bash
# Ensure yabai space focus/move commands succeed by reloading the scripting addition on demand.

set -euo pipefail

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

usage() {
  cat <<'USAGE' >&2
Usage: yabai-space-helper.sh <focus|move> <space-id>

Ensures the yabai scripting addition is loaded before attempting to focus a
Space or move the focused window to another Space.
USAGE
  exit 2
}

if [[ $# -lt 2 ]]; then
  usage
fi

action="$1"
shift
target="$1"
shift || true

case "$action" in
  focus|move)
    ;;
  *)
    usage
    ;;
esac

log_error() {
  local message="$1"
  local log_root="${HOME:-/tmp}/Library/Logs/themectl"
  mkdir -p "$log_root"
  printf '%s %s\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$message" >> "$log_root/yabai-space-helper.log"
}

if [[ ! "$target" =~ ^[0-9]+$ ]]; then
  log_error "invalid target '$target'"
  echo "[yabai-space-helper] Target must be numeric (got '$target')" >&2
  exit 2
fi

yabai_bin="${YABAI_BIN:-$(command -v yabai || true)}"
sudo_bin="${SUDO_BIN:-$(command -v sudo || true)}"

if [[ -z "$yabai_bin" ]]; then
  log_error "yabai binary not found"
  echo "[yabai-space-helper] Unable to locate yabai binary" >&2
  exit 1
fi

run_action() {
  case "$action" in
    focus)
      "$yabai_bin" -m space --focus "$target"
      ;;
    move)
      "$yabai_bin" -m window --space "$target"
      ;;
  esac
}

maybe_reload_sa() {
  if [[ -z "$sudo_bin" ]]; then
    log_error "sudo not found; cannot reload scripting addition"
    return 1
  fi

  if "$sudo_bin" -n "$yabai_bin" --load-sa >/dev/null 2>&1; then
    return 0
  fi

  log_error "sudo failed to load scripting addition"
  return 1
}

if run_action; then
  exit 0
fi

if maybe_reload_sa && run_action; then
  exit 0
fi

log_error "failed to ${action} space ${target}"
exit 1
