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
  # Only log if we can create the directory (skip in sandboxed environments like nix build)
  if mkdir -p "$log_root" 2>/dev/null; then
    printf '%s %s\n' "$(date +'%Y-%m-%dT%H:%M:%S')" "$message" >> "$log_root/yabai-space-helper.log" 2>/dev/null || true
  fi
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
      # Query which display the target space is on
      target_display=$("$yabai_bin" -m query --spaces | jq -r ".[] | select(.index == $target) | .display" 2>/dev/null || echo "")

      # If we found the display, focus it first (works without SA)
      if [[ -n "$target_display" ]] && [[ "$target_display" != "null" ]]; then
        "$yabai_bin" -m display --focus "$target_display" 2>/dev/null || true
      fi

      # Then try to focus the space (requires SA)
      "$yabai_bin" -m space --focus "$target"
      ;;
    move)
      "$yabai_bin" -m window --space "$target"
      ;;
  esac
}

check_sip_allows_yabai() {
  # Check if SIP configuration allows yabai scripting addition
  # Returns 0 if SIP is disabled or debugging restrictions are off
  local sip_status
  sip_status=$(csrutil status 2>/dev/null | tr '[:upper:]' '[:lower:]')

  # SIP fully disabled
  if [[ "$sip_status" == *"disabled"* ]]; then
    return 0
  fi

  # Debugging restrictions disabled (allows yabai SA)
  if [[ "$sip_status" == *"debugging restrictions: disabled"* ]]; then
    return 0
  fi

  # SIP is enabled with debugging restrictions - yabai SA won't work
  return 1
}

maybe_reload_sa() {
  # Don't try to reload SA if SIP won't allow it (avoids notification spam)
  if ! check_sip_allows_yabai; then
    log_error "SIP enabled - scripting addition unavailable (workspace switching disabled)"
    return 1
  fi

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

# Try to reload SA if SIP allows it (won't spam if SIP blocks it)
if maybe_reload_sa && run_action; then
  exit 0
fi

log_error "failed to ${action} space ${target} - scripting addition may not be loaded"
exit 1
