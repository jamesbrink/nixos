#!/usr/bin/env bash
set -euo pipefail

# Follow whichever Strata model llama-swap has loaded: open `strata-cli
# monitor` on its backend and reopen it on the new port when the model
# switches. STRATA_PORTS and STRATA_SWAP_URL come from the NixOS config.
# Extra arguments pass through to `strata-cli monitor` (e.g. --once).
: "${STRATA_PORTS:?}" "${STRATA_SWAP_URL:?}"
interval=${STRATA_MONITOR_INTERVAL:-2}

# The backend URL of the loaded Strata model, or nothing.
current() {
  curl -fsS -m 3 "$STRATA_SWAP_URL/running" 2>/dev/null |
    jq -r --arg ports "$STRATA_PORTS" '
      ($ports | split(" ")) as $p
      | .running[]
      | select(.state == "ready")
      | select((.proxy | capture(":(?<port>[0-9]+)$").port) as $x | $p | index($x))
      | .proxy' |
    head -n 1
}

running_names() {
  curl -fsS -m 3 "$STRATA_SWAP_URL/running" 2>/dev/null |
    jq -r '[.running[] | "\(.model) (\(.state))"] | join(", ") | if . == "" then "nothing" else . end' ||
    echo "llama-swap unreachable"
}

restore_tty() {
  # A killed Textual app leaves mouse, focus and paste reporting on, which
  # prints mouse moves as text: turn every such mode off explicitly.
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1015l\e[?1004l\e[?2004l' >/dev/tty 2>/dev/null || true
  stty sane 2>/dev/null || true
  tput rmcup 2>/dev/null || true
  tput cnorm 2>/dev/null || true
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

trap 'restore_tty; exit 130' INT TERM
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
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$interval"
    if [ "$(current)" != "$url" ]; then
      switched=1
      # Background jobs ignore SIGINT without job control, so TERM it;
      # restore_tty below undoes the terminal modes it leaves behind.
      kill "$pid" 2>/dev/null || true
      break
    fi
  done
  wait "$pid" 2>/dev/null && status=0 || status=$?
  restore_tty
  # The operator quit the monitor (q); a model switch reopens it instead.
  [ -n "$switched" ] || exit "$status"
  printf 'Strata model changed; reconnecting...\n'
done
