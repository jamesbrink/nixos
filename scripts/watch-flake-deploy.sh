#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

ACTION="run"
INPUT_NAME="mold"
HOST_NAME="hal9000"
INTERVAL_SECONDS=300
ONCE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: watch-flake-deploy.sh [start|stop|status|run] [options]

Poll a remote flake input and deploy a host when its locked revision changes.

Actions:
  start                 Start the watcher in the background
  stop                  Stop the background watcher
  status                Show watcher status and recent log output
  run                   Run the watcher in the foreground (default)

Options:
  --input <name>        Flake input to watch (default: mold)
  --host <hostname>     Host to deploy (default: hal9000)
  --interval <seconds>  Poll interval (default: 300)
  --once                Check once and exit
  --dry-run             Report an available update without changing or deploying
  -h, --help            Show this help

The live deployment is always invoked as:
  nix develop -c deploy <hostname>

Runtime state and logs are stored under the repository's Git directory.
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    start|stop|status|run)
      ACTION="$1"
      shift
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_NAME="${2:?--input requires a value}"
      shift 2
      ;;
    --host)
      HOST_NAME="${2:?--host requires a value}"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="${2:?--interval requires a value}"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! "$INPUT_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Error: Invalid input name '$INPUT_NAME'." >&2
  exit 1
fi

if [[ ! "$HOST_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Error: Invalid host name '$HOST_NAME'." >&2
  exit 1
fi

if [[ ! "$INTERVAL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Interval must be a positive integer." >&2
  exit 1
fi

GIT_STATE_ROOT=$(git -C "$REPO_ROOT" rev-parse --git-path watch-flake-deploy)
if [[ "$GIT_STATE_ROOT" != /* ]]; then
  GIT_STATE_ROOT="$REPO_ROOT/$GIT_STATE_ROOT"
fi

WATCH_KEY="${INPUT_NAME}-${HOST_NAME}"
STATE_DIR="$GIT_STATE_ROOT/$WATCH_KEY"
PID_FILE="$STATE_DIR/watcher.pid"
DEPLOYED_REV_FILE="$STATE_DIR/deployed-revision"
LOG_FILE="$STATE_DIR/watcher.log"
LOCK_DIR="$STATE_DIR/runner.lock"
LAUNCHD_LABEL="io.urandom.nixos.watch-flake-deploy.${INPUT_NAME}.${HOST_NAME}"
LAUNCHD_PLIST_DIR="$HOME/Library/LaunchAgents"
LAUNCHD_PLIST="$LAUNCHD_PLIST_DIR/$LAUNCHD_LABEL.plist"
LAUNCHD_DOMAIN="gui/$(id -u)"

mkdir -p "$STATE_DIR"

log() {
  printf '%s [%s/%s] %s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$INPUT_NAME" \
    "$HOST_NAME" \
    "$*"
}

read_pid() {
  if [[ -s "$PID_FILE" ]]; then
    cat "$PID_FILE"
  fi
}

is_running() {
  local pid
  pid=$(read_pid)
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

is_launchd_loaded() {
  [[ "$(uname -s)" == "Darwin" ]] &&
    launchctl print "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" >/dev/null 2>&1
}

locked_revision() {
  jq -er --arg input "$INPUT_NAME" \
    '.nodes[$input].locked.rev' \
    "$REPO_ROOT/flake.lock"
}

input_url() {
  local input_type owner repo ref url
  input_type=$(jq -er --arg input "$INPUT_NAME" \
    '.nodes[$input].original.type' \
    "$REPO_ROOT/flake.lock")

  case "$input_type" in
    github|gitlab|sourcehut)
      owner=$(jq -er --arg input "$INPUT_NAME" \
        '.nodes[$input].original.owner' \
        "$REPO_ROOT/flake.lock")
      repo=$(jq -er --arg input "$INPUT_NAME" \
        '.nodes[$input].original.repo' \
        "$REPO_ROOT/flake.lock")
      ref=$(jq -r --arg input "$INPUT_NAME" \
        '.nodes[$input].original.ref // empty' \
        "$REPO_ROOT/flake.lock")
      url="$input_type:$owner/$repo"
      if [[ -n "$ref" ]]; then
        url="$url/$ref"
      fi
      printf '%s\n' "$url"
      ;;
    git)
      jq -er --arg input "$INPUT_NAME" \
        '.nodes[$input].original.url' \
        "$REPO_ROOT/flake.lock"
      ;;
    *)
      echo "Error: Input '$INPUT_NAME' has unsupported type '$input_type'." >&2
      return 1
      ;;
  esac
}

upstream_revision() {
  local url metadata
  url=$(input_url)
  metadata=$(nix flake metadata --json --refresh "$url")
  jq -er '.revision' <<<"$metadata"
}

record_deployed_revision() {
  local revision="$1"
  printf '%s\n' "$revision" >"$DEPLOYED_REV_FILE"
}

deploy_revision() {
  local revision="$1"

  if [[ "$DRY_RUN" == true ]]; then
    log "Dry run: would deploy revision $revision."
    return 0
  fi

  log "Deploying revision $revision."
  if ! (
    cd "$REPO_ROOT"
    nix develop -c deploy "$HOST_NAME"
  ); then
    log "Deployment failed; revision $revision remains pending for retry."
    return 1
  fi

  if ! (
    cd "$REPO_ROOT"
    nix develop -c health-check "$HOST_NAME"
  ); then
    log "Post-deploy health check failed; revision $revision remains pending for retry."
    return 1
  fi

  record_deployed_revision "$revision"
  log "Deployment and health check succeeded for revision $revision."
}

check_once() {
  local current_revision remote_revision deployed_revision updated_revision

  current_revision=$(locked_revision)
  if ! remote_revision=$(upstream_revision); then
    log "Unable to resolve the upstream revision; will retry."
    return 1
  fi

  deployed_revision=""
  if [[ -s "$DEPLOYED_REV_FILE" ]]; then
    deployed_revision=$(cat "$DEPLOYED_REV_FILE")
  fi

  if [[ "$remote_revision" != "$current_revision" ]]; then
    log "Update available: $current_revision -> $remote_revision."
    if [[ "$DRY_RUN" == true ]]; then
      log "Dry run: would update '$INPUT_NAME' and deploy '$HOST_NAME'."
      return 0
    fi

    if ! (
      cd "$REPO_ROOT"
      nix flake update "$INPUT_NAME"
    ); then
      log "Failed to update '$INPUT_NAME'; will retry."
      return 1
    fi

    updated_revision=$(locked_revision)
    git -C "$REPO_ROOT" add -- flake.lock
    log "Updated and staged '$INPUT_NAME' at revision $updated_revision."
    deploy_revision "$updated_revision"
    return
  fi

  if [[ -z "$deployed_revision" ]]; then
    record_deployed_revision "$current_revision"
    log "Initialized deployment state at current revision $current_revision."
  elif [[ "$deployed_revision" != "$current_revision" ]]; then
    log "Locked revision $current_revision is pending deployment."
    deploy_revision "$current_revision"
  else
    log "No update available; current revision is $current_revision."
  fi
}

acquire_runner_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  if is_running; then
    echo "Error: Watcher is already running with PID $(read_pid)." >&2
    return 1
  fi

  rmdir "$LOCK_DIR" 2>/dev/null || {
    echo "Error: Unable to clear stale runner lock '$LOCK_DIR'." >&2
    return 1
  }
  mkdir "$LOCK_DIR"
}

run_watcher() {
  acquire_runner_lock
  printf '%s\n' "$$" >"$PID_FILE"
  trap 'rm -f "$PID_FILE"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
  trap 'exit 0' INT TERM

  log "Watcher started with a ${INTERVAL_SECONDS}s interval."
  while true; do
    check_once || true
    if [[ "$ONCE" == true ]]; then
      break
    fi
    sleep "$INTERVAL_SECONDS"
  done
  log "Watcher stopped."
}

start_watcher() {
  local -a args
  local attempts launchd_dry_run_argument loaded_plist

  if is_running; then
    if [[ "$(uname -s)" == "Darwin" && ! -f "$LAUNCHD_PLIST" ]]; then
      loaded_plist=$(launchctl print "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" |
        sed -n 's/^[[:space:]]*path = //p' | head -n 1)
      if [[ ! -f "$loaded_plist" ]]; then
        echo "Error: Unable to find the loaded LaunchAgent plist." >&2
        return 1
      fi
      mkdir -p "$LAUNCHD_PLIST_DIR"
      cp "$loaded_plist" "$LAUNCHD_PLIST"
      plutil -lint "$LAUNCHD_PLIST" >/dev/null
      echo "Installed persistent LaunchAgent at $LAUNCHD_PLIST."
    fi

    echo "Watcher is already running with PID $(read_pid)."
    echo "Log: $LOG_FILE"
    return 0
  fi

  rm -f "$PID_FILE"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  args=(run --input "$INPUT_NAME" --host "$HOST_NAME" --interval "$INTERVAL_SECONDS")
  if [[ "$DRY_RUN" == true ]]; then
    args+=(--dry-run)
    launchd_dry_run_argument="    <string>--dry-run</string>"
  else
    launchd_dry_run_argument=""
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    if is_launchd_loaded; then
      launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL"
    fi

    mkdir -p "$LAUNCHD_PLIST_DIR"
    cat >"$LAUNCHD_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCHD_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_PATH</string>
    <string>run</string>
    <string>--input</string>
    <string>$INPUT_NAME</string>
    <string>--host</string>
    <string>$HOST_NAME</string>
    <string>--interval</string>
    <string>$INTERVAL_SECONDS</string>
$launchd_dry_run_argument
  </array>
  <key>WorkingDirectory</key>
  <string>$REPO_ROOT</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$PATH</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
EOF
    plutil -lint "$LAUNCHD_PLIST" >/dev/null
    attempts=0
    until launchctl bootstrap "$LAUNCHD_DOMAIN" "$LAUNCHD_PLIST"; do
      ((attempts += 1))
      if ((attempts >= 5)); then
        echo "Error: Failed to bootstrap LaunchAgent after $attempts attempts." >&2
        return 1
      fi
      sleep 1
    done
  else
    nohup "$SCRIPT_PATH" "${args[@]}" >>"$LOG_FILE" 2>&1 </dev/null &
    printf '%s\n' "$!" >"$PID_FILE"
  fi
  sleep 1

  if ! is_running; then
    echo "Error: Watcher failed to start. See $LOG_FILE." >&2
    return 1
  fi

  echo "Started watcher with PID $(read_pid)."
  echo "Log: $LOG_FILE"
}

stop_watcher() {
  local pid attempts

  if is_launchd_loaded; then
    pid=$(read_pid)
    launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL"
    rm -f "$LAUNCHD_PLIST"
    rm -f "$PID_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    echo "Stopped launchd watcher${pid:+ PID $pid}."
    return 0
  fi

  if ! is_running; then
    echo "Watcher is not running."
    if [[ "$(uname -s)" == "Darwin" ]]; then
      rm -f "$LAUNCHD_PLIST"
    fi
    rm -f "$PID_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    return 0
  fi

  pid=$(read_pid)
  kill "$pid"
  attempts=0
  while kill -0 "$pid" 2>/dev/null && ((attempts < 50)); do
    sleep 0.1
    ((attempts += 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    echo "Error: Watcher PID $pid did not stop." >&2
    return 1
  fi

  echo "Stopped watcher PID $pid."
}

show_status() {
  if is_running; then
    echo "Watcher is running with PID $(read_pid)."
  else
    echo "Watcher is not running."
  fi
  echo "Input: $INPUT_NAME"
  echo "Host: $HOST_NAME"
  echo "Log: $LOG_FILE"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if [[ -f "$LAUNCHD_PLIST" ]]; then
      echo "Persistence: installed LaunchAgent at $LAUNCHD_PLIST"
    else
      echo "Persistence: LaunchAgent is not installed"
    fi
  fi
  if [[ -f "$LOG_FILE" ]]; then
    echo
    tail -n 20 "$LOG_FILE"
  fi
}

case "$ACTION" in
  start)
    start_watcher
    ;;
  stop)
    stop_watcher
    ;;
  status)
    show_status
    ;;
  run)
    run_watcher
    ;;
esac
