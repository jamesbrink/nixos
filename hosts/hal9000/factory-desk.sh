# factory-desk: James's "desk mode" switch for hal9000 (docs/factory-desk.md).
# The settings above this line come from hosts/hal9000/factory-desk.nix.
#
#   factory-desk on [--now] [--for 4h|90m]   stop Quantierra work on this host (local switch)
#   factory-desk off                         lift the local switch
#   factory-desk status [--json]             effective state, where it came from, the units
#   factory-desk sync                        one pass: ask the hub, apply local OR factory desk
#   factory-desk loop                        sync every LOOP_SECS s (factory-desk-sync.service)
#   factory-desk gh-drain <unit>             stop a GitHub runner once its job ends (template unit)
#   factory-desk shutdown-hook               tell the hub the coming runner stops are planned

SELF=$0
LOCAL_FLAG=$STATE_DIR/local
STATE_JSON=$RUN_DIR/state.json
HUB_CACHE=$RUN_DIR/hub.json
STOPPED_DIR=$RUN_DIR/stopped
LOWERED_DIR=$RUN_DIR/lowered
REMOTE_MARKER="# written by factory-desk: remove with factory-desk off"

log() { echo "factory-desk: $*"; }
die() {
  echo "factory-desk: $*" >&2
  exit 1
}
need_root() { ((EUID == 0)) || die "run as root (sudo factory-desk $*)"; }
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date -u -d "$1" +%s 2>/dev/null; }
is_active() { systemctl is-active --quiet "$1"; }
system_state() { systemctl is-system-running 2>/dev/null || true; }

# 4h, 90m, 1h30m, 2d, 45s -> seconds.
parse_duration() {
  local rest=$1 total=0 n u
  [[ $rest =~ ^([0-9]+[dhms])+$ ]] || return 1
  while [[ $rest =~ ^([0-9]+)([dhms])(.*)$ ]]; do
    n=$((10#${BASH_REMATCH[1]})) u=${BASH_REMATCH[2]} rest=${BASH_REMATCH[3]}
    case $u in
    d) total=$((total + n * 86400)) ;;
    h) total=$((total + n * 3600)) ;;
    m) total=$((total + n * 60)) ;;
    s) total=$((total + n)) ;;
    esac
  done
  ((total > 0)) || return 1
  echo "$total"
}

runner_podman() {
  timeout 15 runuser -u "$RUNNER_USER" -- env HOME="$RUNNER_HOME" XDG_RUNTIME_DIR="$RUNNER_RUNTIME" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNNER_RUNTIME/bus" "$PODMAN" "$@"
}

# ---- the hub --------------------------------------------------------------------------------

# Path of runner n's state volume, cached (a path, not a secret) so the shutdown hook needs no podman.
runner_volume() {
  local n=$1 cached=$RUN_DIR/volume-$1 vol
  if [[ -s $cached ]] && vol=$(cat "$cached") && [[ -d $vol ]]; then
    echo "$vol"
    return 0
  fi
  vol=$(runner_podman volume inspect "factory-runner-hal9000-$n-state" --format '{{.Mountpoint}}' 2>/dev/null) || vol=
  if [[ -z $vol || ! -d $vol ]]; then
    vol=$RUNNER_HOME/.local/share/containers/storage/volumes/factory-runner-hal9000-$n-state/_data
    [[ -d $vol ]] || return 1
  fi
  printf '%s\n' "$vol" >"$cached"
  echo "$vol"
}

# One runner's worker credential on stdout. Read as root at call time; never stored or logged.
runner_credential() {
  local vol cred
  vol=$(runner_volume "$1") || return 1
  # the volume is the container's to write: never follow a link it left there
  [[ -f $vol/credential.json && ! -L $vol/credential.json && -r $vol/credential.json ]] || return 1
  cred=$(jq -r '.credential // empty' "$vol/credential.json" 2>/dev/null) || return 1
  [[ $cred =~ ^[[:graph:]]+$ ]] || return 1
  printf '%s' "$cred"
}

# hub_call GET | hub_call POST '<json>': sets HUB_CODE (000 = unreachable or no credential, bad =
# a 200 that is not a desk answer) and HUB_BODY. The credential reaches curl as a header file on a
# pipe (printf is a builtin), never in argv or on disk. A 401 tries the other runner's credential.
hub_call() {
  local method=$1 body=${2:-} n cred out
  local -a extra=()
  HUB_CODE=000 HUB_BODY=
  if [[ -n $body ]]; then extra=(-H 'Content-Type: application/json' --data-binary "$body"); fi
  for n in $RUNNER_NUMBERS; do
    cred=$(runner_credential "$n") || continue
    out=$(curl -sS --connect-timeout "$HUB_CONNECT_TIMEOUT" --max-time "$HUB_MAX_TIME" -X "$method" \
      -H @<(printf 'Authorization: Bearer %s\n' "$cred") "${extra[@]}" \
      -w '\n%{http_code}' "$HUB_URL" 2>/dev/null) || out=$'\n000'
    HUB_CODE=${out##*$'\n'}
    HUB_BODY=${out%$'\n'*}
    [[ $HUB_CODE == 401 ]] || break
  done
  cred=
  [[ $HUB_CODE =~ ^[0-9]{3}$ ]] || HUB_CODE=000
  if [[ $HUB_CODE == 200 ]] && ! jq -e 'type == "object" and has("desk")' >/dev/null 2>&1 <<<"$HUB_BODY"; then
    HUB_CODE=bad
  fi
  return 0
}

save_answer() {
  local tmp
  tmp=$(mktemp "$RUN_DIR/.hub.XXXXXX")
  jq -c --argjson at "$NOW" '{at: $at, answer: .}' <<<"$HUB_BODY" >"$tmp" && mv -f "$tmp" "$HUB_CACHE"
  ANSWER=$HUB_BODY ANSWER_AT=$NOW FRESH=1
}

hub_post() { # on(true|false) why
  local msg prev
  hub_call POST "$(jq -cn --argjson on "$1" --arg why "$2" '{protocol: 1, on: $on, why: $why}')"
  case $HUB_CODE in
  200)
    msg="told the hub: desk on=$1 (why $2)"
    save_answer
    ;;
  409) msg="the hub refused desk on=$1 (409: not a desk this host set)" ;;
  *) msg="could not tell the hub desk on=$1 (why $2): HTTP $HUB_CODE; each pass retries" ;;
  esac
  # A refusal or failure repeats every pass: log it once.
  prev=$(cat "$RUN_DIR/post.status" 2>/dev/null || true)
  if [[ $HUB_CODE == 200 || $msg != "$prev" ]]; then log "$msg"; fi
  printf '%s\n' "$msg" >"$RUN_DIR/post.status"
}

# ---- what the units are doing ---------------------------------------------------------------

unit_cgroup_pids() {
  local cg
  cg=$(systemctl show -p ControlGroup --value "$1" 2>/dev/null) || return 0
  [[ -n $cg && -d $CGROUP_ROOT$cg ]] || return 0
  find "$CGROUP_ROOT$cg" -name cgroup.procs -exec cat {} + 2>/dev/null || true
}

gh_busy() { # a Runner.Worker process = a job is running
  local pid
  for pid in $(unit_cgroup_pids "$1"); do
    [[ $(cat "$PROC_ROOT/$pid/comm" 2>/dev/null) == Runner.Worker ]] && return 0
  done
  return 1
}

# 0 idle, 1 busy, 2 unsure. A job runs as the container's factory-job user; an idle runner is
# only root's tini and bun.
runner_idle_podman() {
  local out users
  out=$(runner_podman top "$1" user 2>/dev/null) || return 2
  users=$(awk 'NR > 1 { print $1 }' <<<"$out")
  [[ -n $users ]] || return 2
  if grep -qvx root <<<"$users"; then return 1; fi
  return 0
}

# Stop a unit for the desk: the marker first (the units' ConditionPathExists keeps Restart= and a
# switch from starting it again), then a non-blocking stop (a worker hands its job back in <100 s).
desk_stop() {
  mkdir -p "$STOPPED_DIR"
  touch "$STOPPED_DIR/$1"
  log "stopping $1 ($2)"
  systemctl stop --no-block "$1" || true
}

# An inactive unit the desk did not stop itself: own it if it stopped during the desk, or the
# desk's condition kept it from starting (a boot with the local flag), so that "off" starts it
# again. One stopped before the desk began (a drained worker, say) stays as it was.
desk_adopt() {
  local u=$1 since=$2 ts cond
  [[ -e $STOPPED_DIR/$u ]] && return 0
  is_active "$u" && return 0
  ts=$(systemctl show -p InactiveEnterTimestamp --value --timestamp=unix "$u" 2>/dev/null || true)
  ts=${ts#@}
  cond=$(systemctl show -p ConditionResult --value "$u" 2>/dev/null || true)
  if [[ $cond != no ]]; then
    [[ $ts =~ ^[0-9]+$ ]] || return 0
    ((ts >= since)) || return 0
  fi
  mkdir -p "$STOPPED_DIR"
  touch "$STOPPED_DIR/$u"
  log "$u is down during the desk: the desk starts it again when it ends"
}

gh_lower() {
  local u=$1 pid ni
  if [[ ! -e $LOWERED_DIR/$u ]]; then
    mkdir -p "$LOWERED_DIR"
    touch "$LOWERED_DIR/$u"
    systemctl set-property --runtime "$u" CPUWeight=1 IOWeight=1 || true
    log "$u is running a job: lowest priority until it ends, then stopped"
  fi
  for pid in $(unit_cgroup_pids "$u"); do
    ni=$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ') || continue
    if [[ $ni =~ ^-?[0-9]+$ ]] && ((ni < 19)); then renice --priority 19 -p "$pid" >/dev/null 2>&1 || true; fi
  done
  systemctl start --no-block "factory-desk-gh-drain@$u.service" || true
}

gh_restore() {
  local u=$1 pid
  [[ -e $LOWERED_DIR/$u ]] || return 0
  systemctl set-property --runtime "$u" CPUWeight= IOWeight= || true
  rm -f "/run/systemd/system.control/$u.service.d/50-CPUWeight.conf" "/run/systemd/system.control/$u.service.d/50-IOWeight.conf"
  for pid in $(unit_cgroup_pids "$u"); do
    if [[ $(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ') == 19 ]]; then renice --priority 0 -p "$pid" >/dev/null 2>&1 || true; fi
  done
  rm -f "$LOWERED_DIR/$u"
  log "$u back to normal priority"
}

remote_env_ours() { [[ -f $REMOTE_ENV && ! -L $REMOTE_ENV && $(head -n 1 "$REMOTE_ENV" 2>/dev/null) == "$REMOTE_MARKER" ]]; }

remote_hold() {
  local dir tmp
  if [[ -L $REMOTE_ENV ]] || { [[ -e $REMOTE_ENV ]] && ! remote_env_ours; }; then
    [[ -e $RUN_DIR/remote-env-foreign ]] || log "$REMOTE_ENV is not ours: left alone (new builds wait for a slot as it says)"
    touch "$RUN_DIR/remote-env-foreign"
  elif ! remote_env_ours; then
    dir=$(dirname "$REMOTE_ENV")
    runuser -u "$REMOTE_USER" -- mkdir -p "$dir"
    tmp=$(mktemp "$dir/.qre-remote.env.XXXXXX")
    printf '%s\nQRE_REMOTE_SLOTS=%s\nQRE_REMOTE_SLOT_WAIT=0\n' "$REMOTE_MARKER" "$REMOTE_SLOTS" >"$tmp"
    chown "$REMOTE_USER:$(id -gn "$REMOTE_USER")" "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$REMOTE_ENV"
    log "remote builds: wrote $REMOTE_ENV (a build finding no free slot exits 75 at once)"
  fi
  if ! is_active "$HOLD_UNIT"; then
    log "remote builds: holding the build slots (running builds keep theirs and finish)"
    systemctl start --no-block "$HOLD_UNIT" || true
  fi
}

remote_release() {
  rm -f "$RUN_DIR/remote-env-foreign"
  if remote_env_ours; then
    rm -f "$REMOTE_ENV"
    log "remote builds: removed $REMOTE_ENV"
  fi
  if is_active "$HOLD_UNIT"; then
    log "remote builds: releasing the build slots"
    systemctl stop --no-block "$HOLD_UNIT" || true
  fi
}

# ---- apply ----------------------------------------------------------------------------------

apply_on() { # source(local|factory) ci(now|finish) since-epoch
  local src=$1 ci=$2 since=$3 u name job idle
  remote_hold
  for u in $FACTORY_UNITS; do
    if ! is_active "$u"; then
      desk_adopt "$u" "$since"
      continue
    fi
    if [[ $src == local ]]; then
      desk_stop "$u" "local desk: the worker hands its job back with its work"
      continue
    fi
    name=${u#factory-runner-}
    job=unknown
    if ((FRESH)); then
      job=$(jq -r --arg n "$name" '[.workers[]? | select(.name == $n)][0] |
        if . == null then "unknown" elif .job == null then "idle" else "busy" end' <<<"$ANSWER" 2>/dev/null) || job=unknown
    fi
    if [[ $job == unknown ]]; then
      idle=0
      runner_idle_podman "$u" || idle=$?
      case $idle in 0) job=idle ;; 1) job=busy ;; *) job=unsure ;; esac
    fi
    if [[ $job == idle ]]; then desk_stop "$u" "factory desk: no job on $name"; fi
  done
  for u in $GH_UNITS; do
    if ! is_active "$u"; then
      desk_adopt "$u" "$since"
      continue
    fi
    if ! gh_busy "$u"; then
      desk_stop "$u" "idle GitHub runner"
    elif [[ $ci == now ]]; then
      desk_stop "$u" "ci now: its job fails with a shutdown signal"
    else
      gh_lower "$u"
    fi
  done
}

apply_off() {
  local u drains
  drains=$(systemctl list-units --plain --no-legend --state=active,activating 'factory-desk-gh-drain@*' 2>/dev/null |
    awk '{ print $1 }') || drains=
  if [[ -n $drains ]]; then
    # shellcheck disable=SC2086 # one unit name per word
    systemctl stop --no-block $drains || true
  fi
  remote_release
  for u in $GH_UNITS $FACTORY_UNITS; do
    gh_restore "$u"
    [[ -e $STOPPED_DIR/$u ]] || continue
    rm -f "$STOPPED_DIR/$u"
    if [[ " $FACTORY_UNITS " == *" $u "* ]] && ! mountpoint -q "$RUNNER_CACHE"; then
      log "not starting $u: $RUNNER_CACHE is not mounted (it starts with storage-ssd-import)"
      continue
    fi
    log "starting $u"
    systemctl start --no-block "$u" || true
  done
}

# ---- sync -----------------------------------------------------------------------------------

write_state() {
  local tmp
  tmp=$(mktemp "$RUN_DIR/.state.XXXXXX")
  jq -n --argjson effective "$1" --arg source "$2" --arg ci "$3" --arg mode "$4" \
    --argjson local "$LOCAL_JSON" --argjson desk "$DESK" \
    --arg code "$HUB_CODE" --argjson now "$NOW" --argjson at "${ANSWER_AT:-null}" '{
      effective: $effective,
      source: (if $source == "" then null else $source end),
      ci: (if $ci == "" then null else $ci end),
      mode: (if $mode == "" then null else $mode end),
      local: $local,
      factory: $desk,
      hub: {last_status: $code, last_answer_at: (if $at == null then null else ($at | todate) end),
            answer_age_s: (if $at == null then null else $now - $at end)},
      updated: ($now | todate)
    }' >"$tmp" && chmod 0644 "$tmp" && mv -f "$tmp" "$STATE_JSON"
}

read_desk() {
  DESK=$(jq -c '.desk // null' <<<"${ANSWER:-null}" 2>/dev/null) || DESK=null
  [[ -n $DESK ]] || DESK=null
  DESK_SRC=$(jq -r '.source // empty' <<<"$DESK" 2>/dev/null) || DESK_SRC=
  DESK_WHY=$(jq -r '.why // empty' <<<"$DESK" 2>/dev/null) || DESK_WHY=
}

sync_once() {
  local until_s prev eff=false src='' ci='' mode='' since
  mkdir -p "$RUN_DIR"
  exec 9>"$RUN_DIR/sync.lock"
  flock -w 120 9 || die "another sync holds $RUN_DIR/sync.lock"
  NOW=$(date +%s) FRESH=0 ANSWER='' ANSWER_AT='' DESK=null DESK_SRC='' DESK_WHY='' LOCAL_JSON=null

  # Shutting down: the runners stop on their own; the shutdown hook spoke to the hub.
  if [[ $(system_state) == stopping ]]; then return 0; fi

  # The local switch; --for runs out here.
  if [[ -f $LOCAL_FLAG ]]; then
    if LOCAL_JSON=$(jq -ce 'select(type == "object")' "$LOCAL_FLAG" 2>/dev/null); then
      until_s=$(jq -r '.until // empty' <<<"$LOCAL_JSON")
      if [[ -n $until_s ]] && until_s=$(epoch "$until_s") && ((NOW >= until_s)); then
        rm -f "$LOCAL_FLAG"
        log "local desk ended: its --for ran out at $(iso "$until_s")"
        LOCAL_JSON=null
      fi
    else
      log "$LOCAL_FLAG is not valid JSON: treated as desk on (now) until it is fixed or removed"
      LOCAL_JSON="{\"since\":\"$(iso "$NOW")\",\"until\":null,\"now\":true,\"invalid\":true}"
    fi
  fi

  # The factory's answer: fresh, else the last good one for at most HUB_TTL s.
  prev=$(cat "$RUN_DIR/hub.status" 2>/dev/null || true)
  hub_call GET
  if [[ $HUB_CODE != "$prev" ]]; then
    log "hub: HTTP $HUB_CODE (was ${prev:-nothing yet})"
    echo "$HUB_CODE" >"$RUN_DIR/hub.status"
  fi
  if [[ $HUB_CODE == 200 ]]; then
    save_answer
  elif [[ -f $HUB_CACHE ]]; then
    ANSWER_AT=$(jq -r '.at // empty' "$HUB_CACHE" 2>/dev/null || true)
    if [[ $ANSWER_AT =~ ^[0-9]+$ ]] && ((NOW - ANSWER_AT <= HUB_TTL)); then
      ANSWER=$(jq -c '.answer' "$HUB_CACHE" 2>/dev/null) || ANSWER=''
    else
      ANSWER='' ANSWER_AT=''
    fi
  fi
  read_desk

  # Keep the hub in line with the local switch, on a fresh answer only (a stale one may be wrong).
  if ((FRESH)); then
    if [[ $LOCAL_JSON != null ]]; then
      if [[ $DESK == null ]] || [[ $DESK_SRC == host && $DESK_WHY != local ]]; then hub_post true local; fi
    elif [[ $DESK_SRC == host ]]; then
      # Our own desk with the local switch off (why local), or the PC is back up (why shutdown).
      hub_post false "${DESK_WHY:-local}"
    fi
    read_desk
  fi

  if [[ $LOCAL_JSON != null ]]; then
    eff=true src=local mode=stop
    ci=$(jq -r 'if .now then "now" else "finish" end' <<<"$LOCAL_JSON")
    since=$(epoch "$(jq -r '.since // empty' <<<"$LOCAL_JSON")") || since=$NOW
  elif [[ $DESK != null && $DESK_SRC != host ]]; then
    # A desk the host set itself (local switch since lifted, or the shutdown) never holds it.
    eff=true src=factory
    ci=$(jq -r 'if .ci == "now" then "now" else "finish" end' <<<"$DESK")
    mode=$(jq -r '.mode // "handoff"' <<<"$DESK")
    since=$(epoch "$(jq -r '.since // empty' <<<"$DESK")") || since=$NOW
  fi

  prev=$(jq -r 'if .effective then "on " + .source else "off" end' "$STATE_JSON" 2>/dev/null || true)
  if [[ $eff == true ]]; then
    [[ $prev == "on $src" ]] || log "desk ON ($src, ci $ci, mode $mode)"
    apply_on "$src" "$ci" "$since"
  else
    [[ $prev == off || -z $prev ]] || log "desk OFF: resuming Quantierra work"
    apply_off
  fi
  write_state "$eff" "$src" "$ci" "$mode"
}

# ---- commands -------------------------------------------------------------------------------

cmd_on() {
  local now=false dur='' until=null since secs tmp
  need_root on
  while (($#)); do
    case $1 in
    --now) now=true ;;
    --for)
      [[ $# -ge 2 ]] || die "--for needs a duration (4h, 90m)"
      dur=$2
      shift
      ;;
    --for=*) dur=${1#--for=} ;;
    *) die "unknown option $1 (factory-desk on [--now] [--for 4h|90m])" ;;
    esac
    shift
  done
  NOW=$(date +%s)
  since=$(jq -r '.since // empty' "$LOCAL_FLAG" 2>/dev/null || true)
  [[ -n $since ]] || since=$(iso "$NOW")
  if [[ -n $dur ]]; then
    secs=$(parse_duration "$dur") || die "bad --for '$dur' (examples: 4h, 90m, 1h30m)"
    until="\"$(iso $((NOW + secs)))\""
  fi
  mkdir -p "$STATE_DIR"
  tmp=$(mktemp "$STATE_DIR/.local.XXXXXX")
  jq -n --arg since "$since" --argjson until "$until" --argjson now "$now" \
    '{since: $since, until: $until, now: $now}' >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$LOCAL_FLAG"
  log "local desk on by ${SUDO_USER:-root} (now $now, until $(jq -r '.until // "factory-desk off"' "$LOCAL_FLAG"))"
  (sync_once)
  cmd_status
}

cmd_off() {
  need_root off
  if [[ -e $LOCAL_FLAG ]]; then
    rm -f "$LOCAL_FLAG"
    log "local desk off by ${SUDO_USER:-root}"
  else
    echo "no local desk was on"
  fi
  (sync_once)
  cmd_status
}

cmd_status() {
  local u s
  if [[ ${1:-} == --json ]]; then
    cat "$STATE_JSON" 2>/dev/null || echo null
    return 0
  fi
  if [[ -f $LOCAL_FLAG ]]; then
    echo "local switch: ON, $(jq -r '"since \(.since), until \(.until // "factory-desk off"), now \(.now)"' "$LOCAL_FLAG" 2>/dev/null || echo '(unreadable flag)')"
  else
    echo "local switch: off"
  fi
  if [[ -f $STATE_JSON ]]; then
    jq -r '"desk: " + (if .effective then "ON (\(.source), ci \(.ci), mode \(.mode))" else "OFF" end),
      "factory desk: " + (if .factory == null then "none" else (.factory | tojson) end),
      "hub: last HTTP \(.hub.last_status), last answer \(.hub.last_answer_at // "never")" +
        (if .hub.answer_age_s == null then "" else " (\(.hub.answer_age_s) s before \(.updated))" end)' "$STATE_JSON"
  else
    echo "desk: no sync yet (is factory-desk-sync.service running?)"
  fi
  for u in $FACTORY_UNITS $GH_UNITS $HOLD_UNIT; do
    s=$(systemctl is-active "$u" 2>/dev/null || true)
    [[ -e $STOPPED_DIR/$u ]] && s="$s, stopped by the desk"
    [[ -e $LOWERED_DIR/$u ]] && s="$s, lowest priority until its job ends"
    printf '  %-34s %s\n' "$u" "$s"
  done
  if remote_env_ours; then
    echo "remote builds: refused at once ($REMOTE_ENV is ours)"
  elif [[ -e $REMOTE_ENV ]]; then
    echo "remote builds: $REMOTE_ENV exists, not ours"
  else
    echo "remote builds: normal"
  fi
}

cmd_gh_drain() {
  local u=${1:-}
  [[ " $GH_UNITS " == *" $u "* ]] || die "gh-drain: '$u' is not one of: $GH_UNITS"
  while is_active "$u"; do
    if ! gh_busy "$u"; then
      desk_stop "$u" "its job ended"
      return 0
    fi
    sleep 0.5
  done
}

cmd_shutdown_hook() {
  [[ $(system_state) == stopping ]] || return 0 # a restart of this unit, not a shutdown
  [[ -e $LOCAL_FLAG ]] && return 0             # the local desk already stopped the runners
  NOW=$(date +%s)
  mkdir -p "$RUN_DIR"
  HUB_CONNECT_TIMEOUT=3 HUB_MAX_TIME=$SHUTDOWN_MAX_TIME
  hub_post true shutdown
}

cmd=${1:-status}
if (($#)); then shift; fi
case $cmd in
on) cmd_on "$@" ;;
off) cmd_off "$@" ;;
status) cmd_status "$@" ;;
sync)
  need_root sync
  sync_once
  ;;
loop)
  need_root loop
  while :; do
    "$SELF" sync || log "sync pass failed (exit $?)"
    sleep "$LOOP_SECS"
  done
  ;;
gh-drain)
  need_root gh-drain
  cmd_gh_drain "$@"
  ;;
shutdown-hook)
  need_root shutdown-hook
  cmd_shutdown_hook
  ;;
-h | --help | help)
  cat <<'EOF'
factory-desk on [--now] [--for 4h|90m]   stop Quantierra work on this host (sudo)
factory-desk off                         lift the local switch (sudo)
factory-desk status [--json]             effective state, where it came from, the units
factory-desk sync                        one pass now (the sync service runs one every 15 s)
EOF
  ;;
*) die "unknown command $cmd (on, off, status, sync; see --help)" ;;
esac
