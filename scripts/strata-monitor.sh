#!/usr/bin/env bash
set -euo pipefail

# Follow whichever Strata model llama-swap has loaded: open `strata-cli
# monitor` on its backend and reopen it on the new port when the model
# switches. STRATA_PORTS and STRATA_SWAP_URL come from the NixOS config.
# Extra arguments pass through to `strata-cli monitor` (e.g. --once).
: "${STRATA_PORTS:?}" "${STRATA_SWAP_URL:?}"
interval=${STRATA_MONITOR_INTERVAL:-2}

# The backend URL of the loaded Strata model, or nothing. Never fails: while
# a model swaps or llama-swap restarts, /running is briefly unreachable, and
# under set -e/pipefail that used to end the script mid-switch.
current() {
  curl -fsS -m 3 "$STRATA_SWAP_URL/running" 2>/dev/null |
    jq -r --arg ports "$STRATA_PORTS" '
      ($ports | split(" ")) as $p
      | .running[]
      | select(.state == "ready")
      | select((.proxy | capture(":(?<port>[0-9]+)$").port) as $x | $p | index($x))
      | .proxy' 2>/dev/null |
    head -n 1 || true
}

running_names() {
  curl -fsS -m 3 "$STRATA_SWAP_URL/running" 2>/dev/null |
    jq -r '[.running[] | "\(.model) (\(.state))"] | join(", ") | if . == "" then "nothing" else . end' ||
    echo "llama-swap unreachable"
}

restore_tty() {
  # A killed Textual app leaves its terminal modes on, and the terminal then
  # types mouse moves, focus events, key codes and window-size reports
  # (e.g. "8;24;281;504;2810t") into the shell. Undo everything Textual's
  # Linux driver turns on: mouse (1000-1016), alternate scroll (1007),
  # focus (1004), bracketed paste (2004), in-band resize (2048), the kitty
  # keyboard protocol (pop with CSI < u), the alternate screen, the hidden
  # cursor and autowrap.
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1007l\e[?1015l\e[?1016l' >/dev/tty 2>/dev/null || true
  printf '\e[?1004l\e[?2004l\e[?2048l\e[<u\e[?1049l\e[?25h\e[?7h' >/dev/tty 2>/dev/null || true
  stty sane </dev/tty 2>/dev/null || true
  drain_tty
}

# Discard what the terminal already sent the dead app (size reports, mouse
# and focus events) so it does not land on the next prompt.
drain_tty() {
  local _junk
  while IFS= read -r -s -t 0.2 -n 4096 _junk </dev/tty; do :; done 2>/dev/null || true
}

for arg in "$@"; do
  if [ "$arg" = "--once" ]; then
    url=$(current)
    [ -n "$url" ] || {
      echo "No Strata model is loaded; llama-swap is running: $(running_names)." >&2
      exit 3
    }
    exec strata-cli monitor --url "$url" "$@"
  fi
done

pid=""
on_signal() {
  [ -z "$pid" ] || kill "$pid" 2>/dev/null || true
  [ -z "$pid" ] || wait "$pid" 2>/dev/null || true
  restore_tty
  exit 130
}
trap on_signal INT TERM HUP
waiting=""
while true; do
  url=$(current)
  if [ -z "$url" ]; then
    now="No Strata model loaded (llama-swap: $(running_names)). Waiting; Ctrl-C to quit."
    [ "$now" = "$waiting" ] || printf '%s\n' "$now"
    waiting=$now
    sleep "$interval"
    continue
  fi
  waiting=""
  # Job control is off in scripts, so give the background monitor the TTY.
  strata-cli monitor --url "$url" "$@" </dev/tty &
  pid=$!
  switched=""
  misses=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$interval"
    if [ "$(current)" = "$url" ]; then
      misses=0
      continue
    fi
    # Two polls in a row, so one slow /running answer is not a switch.
    misses=$((misses + 1))
    [ "$misses" -ge 2 ] || continue
    switched=1
    # Background jobs ignore SIGINT without job control, so TERM it;
    # restore_tty below undoes the terminal modes it leaves behind.
    kill "$pid" 2>/dev/null || true
    break
  done
  wait "$pid" 2>/dev/null && status=0 || status=$?
  pid=""
  restore_tty
  # The operator quit the monitor (q); a model switch reopens it instead.
  [ -n "$switched" ] || exit "$status"
  printf 'Strata model changed; reconnecting...\n'
done
