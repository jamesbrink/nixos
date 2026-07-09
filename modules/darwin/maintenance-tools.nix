{ pkgs, ... }:

let
  projectCleanup = pkgs.writeShellScriptBin "project-cleanup" ''
    set -euo pipefail

    TARGET="$HOME/Projects"
    INCLUDE_VENVS=0
    for arg in "$@"; do
      case "$arg" in
        --venvs) INCLUDE_VENVS=1 ;;
        -h | --help)
          echo "Usage: project-cleanup [--venvs] [dir]"
          echo ""
          echo "Scans dir (default ~/Projects) for project build caches and removes them."
          echo "  --venvs  also remove .venv/venv virtualenvs (uv recreates them quickly)"
          exit 0
          ;;
        *) TARGET="$arg" ;;
      esac
    done
    TOTAL_FREED=0

    green()  { printf '\033[0;32m%s\033[0m' "$1"; }
    bold()   { printf '\033[1m%s\033[0m' "$1"; }

    bytes_to_human() {
      local b=$1
      if   (( b >= 1073741824 )); then printf "%.1fG" "$(echo "$b / 1073741824" | bc -l)"
      elif (( b >= 1048576 ));    then printf "%.1fM" "$(echo "$b / 1048576" | bc -l)"
      elif (( b >= 1024 ));       then printf "%.1fK" "$(echo "$b / 1024" | bc -l)"
      else printf "%dB" "$b"
      fi
    }

    get_size_bytes() {
      du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
    }

    echo ""
    bold "Project Cache Cleaner"; echo ""
    echo "Scanning $(bold "$TARGET") ..."
    echo ""

    declare -a TARGETS=()

    add() {
      local type=$1 path=$2 size
      size=$(get_size_bytes "$path")
      TARGETS+=("$type|$path|$size")
    }

    # scan TYPE NAME — find directories by name, skipping matches nested
    # inside node_modules or virtualenvs (their parent gets removed anyway)
    scan() {
      local type=$1 name=$2
      while IFS= read -r d; do
        add "$type" "$d"
      done < <(find "$TARGET" -maxdepth 6 -name "$name" -type d \
        -not -path "*/node_modules/*" -not -path "*/.venv/*" -not -path "*/venv/*" \
        2>/dev/null)
    }

    # scan_marker TYPE MARKER SUBDIR — find SUBDIR next to a marker file, so
    # generic names like target/ or build/ only match real projects
    scan_marker() {
      local type=$1 marker=$2 sub=$3 dir
      while IFS= read -r f; do
        dir="$(dirname "$f")"
        if [ -d "$dir/$sub" ]; then
          add "$type" "$dir/$sub"
        fi
      done < <(find "$TARGET" -maxdepth 5 -name "$marker" -type f \
        -not -path "*/node_modules/*" 2>/dev/null)
    }

    # Rust
    scan_marker rust Cargo.toml target

    # JS/TS package and framework caches
    while IFS= read -r d; do
      add node "$d"
    done < <(find "$TARGET" -maxdepth 5 -name node_modules -type d -not -path "*/node_modules/*/node_modules" 2>/dev/null)
    for name in .next .turbo .parcel-cache .vite .nuxt .svelte-kit .astro .angular; do
      scan js "$name"
    done

    # Python caches
    for name in __pycache__ .pytest_cache .mypy_cache .ruff_cache .tox .nox; do
      scan python "$name"
    done
    scan python "*.egg-info"
    if [ "$INCLUDE_VENVS" = 1 ]; then
      scan venv .venv
      scan venv venv
    fi

    # JVM: maven target/ and gradle build/.gradle next to their build files
    scan_marker maven pom.xml target
    scan_marker gradle build.gradle build
    scan_marker gradle build.gradle.kts build
    scan_marker gradle build.gradle .gradle
    scan_marker gradle build.gradle.kts .gradle

    # Go vendored deps and local build caches
    scan_marker go go.mod vendor
    scan_marker go go.mod .cache

    # Elixir
    scan_marker elixir mix.exs _build

    # Zig
    for name in zig-cache .zig-cache zig-out; do
      scan zig "$name"
    done

    # Terraform provider/module cache (re-fetched by terraform init)
    scan terraform .terraform

    # .direnv holds each devShell's Nix GC root — deleting it frees only KB
    # but unroots multi-GB closures and forces slow rebuilds. Use `nix-gc`.

    # Nix result symlinks: ~0 bytes themselves, but each is a GC root pinning
    # a whole store closure — deleting them lets the next nix-gc reclaim it
    while IFS= read -r l; do
      TARGETS+=("nix-root|$l|0")
    done < <(find "$TARGET" -maxdepth 5 -name "result*" -type l -lname '/nix/store/*' 2>/dev/null)

    # Swift .build directories (SPM)
    while IFS= read -r d; do
      add swift "$d"
    done < <(find "$TARGET" -maxdepth 5 -name ".build" -type d -execdir test -e Package.swift \; -print 2>/dev/null)

    # Swift .swiftpm caches
    scan swift .swiftpm

    # Xcode DerivedData is user-level, not project-level: cache-cleanup --deep

    if [ ''${#TARGETS[@]} -eq 0 ]; then
      echo "No caches found."
      exit 0
    fi

    IFS=$'\n' SORTED=($(for t in "''${TARGETS[@]}"; do echo "$t"; done | sort -t'|' -k3 -rn))
    unset IFS

    echo "Found ''${#SORTED[@]} cache directories:"
    echo ""
    printf "  %-9s  %-10s  %s\n" "TYPE" "SIZE" "PATH"
    printf "  %-9s  %-10s  %s\n" "---------" "----------" "----"

    for entry in "''${SORTED[@]}"; do
      IFS='|' read -r type path size <<< "$entry"
      human=$(bytes_to_human "$size")
      if [ "$type" = "nix-root" ]; then
        human="(root)"
      fi
      rel="''${path#$TARGET/}"
      printf "  %-9s  %-10s  %s\n" "$type" "$human" "$rel"
      TOTAL_FREED=$((TOTAL_FREED + size))
    done

    echo ""
    echo "Total reclaimable: $(bold "$(bytes_to_human $TOTAL_FREED)") (plus whatever nix-gc frees after nix-root removal)"
    if [ "$INCLUDE_VENVS" = 0 ]; then
      echo "Virtualenvs skipped — rerun with --venvs to include them."
    fi
    echo ""

    read -rp "Remove all? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi

    echo ""
    for entry in "''${SORTED[@]}"; do
      IFS='|' read -r type path size <<< "$entry"
      rel="''${path#$TARGET/}"

      if [ "$type" = "rust" ]; then
        echo "  cargo clean: $rel"
        (cd "$(dirname "$path")" && cargo clean 2>/dev/null) || rm -rf "$path"
      else
        echo "  rm -rf: $rel"
        rm -rf "$path"
      fi
    done

    echo ""
    green "Done."; echo " Freed ~$(bytes_to_human $TOTAL_FREED)"
    echo "Removed Nix GC roots free store space at the next nix-gc run."
    echo ""
  '';

  cacheCleanup = pkgs.writeShellScriptBin "cache-cleanup" ''
    set -euo pipefail

    DEEP=0
    ASSUME_YES=0
    for arg in "$@"; do
      case "$arg" in
        --deep) DEEP=1 ;;
        --yes | -y) ASSUME_YES=1 ;;
        -h | --help)
          echo "Usage: cache-cleanup [--deep] [--yes]"
          echo ""
          echo "Clears user-level tool caches. Everything in the default (safe) tier is"
          echo "rebuilt transparently on next use — the only cost is re-downloading."
          echo ""
          echo "  --deep  also clear caches whose loss slows the next build or debug"
          echo "          session (go modcache, maven, cargo registry, gradle,"
          echo "          Xcode DerivedData / iOS DeviceSupport)"
          echo "  --yes   skip confirmation prompt"
          exit 0
          ;;
      esac
    done

    green()  { printf '\033[0;32m%s\033[0m' "$1"; }
    bold()   { printf '\033[1m%s\033[0m' "$1"; }
    dim()    { printf '\033[2m%s\033[0m' "$1"; }

    bytes_to_human() {
      local b=$1
      if   (( b >= 1073741824 )); then printf "%.1fG" "$(echo "$b / 1073741824" | bc -l)"
      elif (( b >= 1048576 ));    then printf "%.1fM" "$(echo "$b / 1048576" | bc -l)"
      elif (( b >= 1024 ));       then printf "%.1fK" "$(echo "$b / 1024" | bc -l)"
      else printf "%dB" "$b"
      fi
    }

    get_size_bytes() {
      du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
    }

    declare -a ENTRIES=()

    # add LABEL TIER METHOD PATH — skip missing/empty caches
    add() {
      local label=$1 tier=$2 method=$3 path=$4 size
      [ -e "$path" ] || return 0
      size=$(get_size_bytes "$path")
      if (( size > 0 )); then
        ENTRIES+=("$label|$tier|$method|$path|$size")
      fi
    }

    echo ""
    bold "User Cache Cleaner"; echo ""
    echo "Scanning caches ..."
    echo ""

    # ---- safe tier: pure caches, rebuilt on demand ----
    add "restic metadata"     safe rm "$HOME/Library/Caches/restic"
    add "uv (Python wheels)"  safe rm "$HOME/.cache/uv"
    add "npm"                 safe rm "$HOME/.npm/_cacache"
    add "pip"                 safe rm "$HOME/Library/Caches/pip"
    add "pip (xdg)"           safe rm "$HOME/.cache/pip"
    add "pnpm store"          safe rm "$HOME/Library/pnpm/store"
    add "pnpm store (xdg)"    safe rm "$HOME/.local/share/pnpm/store"
    add "yarn"                safe rm "$HOME/Library/Caches/Yarn"
    add "sccache"             safe rm "$HOME/Library/Caches/Mozilla.sccache"
    add "cargo-xwin"          safe rm "$HOME/Library/Caches/cargo-xwin"
    add "nix eval cache"      safe rm "$HOME/.cache/nix"
    add "pre-commit"          safe rm "$HOME/.cache/pre-commit"
    for d in puppeteer playwright ms-playwright playwright-browsers rod chrome-devtools-mcp; do
      add "browsers: $d"      safe rm "$HOME/.cache/$d"
    done
    add "browsers: playwright (darwin)" safe rm "$HOME/Library/Caches/ms-playwright"
    if command -v brew >/dev/null 2>&1; then
      add "homebrew"          safe brew "$(brew --cache)"
    fi
    if command -v go >/dev/null 2>&1; then
      add "go build cache"    safe rm "$(go env GOCACHE)"
    fi

    # ---- deep tier: safe to delete, but the next build/debug pays to refill ----
    if (( DEEP )); then
      if command -v go >/dev/null 2>&1; then
        add "go module cache" deep gomod "$(go env GOMODCACHE)"
      fi
      add "maven repository"  deep rm "$HOME/.m2/repository"
      add "cargo registry"    deep rm "$HOME/.cargo/registry"
      add "gradle caches"     deep rm "$HOME/.gradle/caches"
      add "Xcode DerivedData" deep rm "$HOME/Library/Developer/Xcode/DerivedData"
      add "iOS DeviceSupport" deep rm "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
      add "CoreSimulator caches" deep rm "$HOME/Library/Developer/CoreSimulator/Caches"
    fi

    if [ ''${#ENTRIES[@]} -eq 0 ]; then
      echo "No caches found."
      exit 0
    fi

    IFS=$'\n' SORTED=($(for e in "''${ENTRIES[@]}"; do echo "$e"; done | sort -t'|' -k5 -rn))
    unset IFS

    TOTAL=0
    printf "  %-6s  %-10s  %s\n" "TIER" "SIZE" "CACHE"
    printf "  %-6s  %-10s  %s\n" "------" "----------" "-----"
    for entry in "''${SORTED[@]}"; do
      IFS='|' read -r label tier method path size <<< "$entry"
      printf "  %-6s  %-10s  %s  %s\n" "$tier" "$(bytes_to_human "$size")" "$label" "$(dim "''${path/#$HOME/\~}")"
      TOTAL=$((TOTAL + size))
    done
    echo ""
    echo "Total reclaimable: $(bold "$(bytes_to_human $TOTAL)")"
    if (( ! DEEP )); then
      dim "Rerun with --deep to include go modcache, maven, cargo registry, gradle, Xcode caches."; echo ""
    fi
    echo ""

    if (( ! ASSUME_YES )); then
      read -rp "Remove all? [y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
      fi
      echo ""
    fi

    for entry in "''${SORTED[@]}"; do
      IFS='|' read -r label tier method path size <<< "$entry"
      echo "  clearing: $label"
      case "$method" in
        brew)
          brew cleanup -s --prune=all >/dev/null 2>&1 || true
          rm -rf "$path"
          ;;
        gomod)
          go clean -modcache 2>/dev/null || rm -rf "$path"
          ;;
        *)
          rm -rf "$path"
          ;;
      esac
    done

    echo ""
    green "Done."; echo " Freed ~$(bytes_to_human $TOTAL)"
    echo ""
    dim "Related: nix-gc (Nix store), project-cleanup (per-project build dirs),"; echo ""
    dim "diskspace (APFS snapshots), xcrun simctl delete all (simulator disks)."; echo ""
    echo ""
  '';

  diskspace = pkgs.writeShellScriptBin "diskspace" ''
    set -euo pipefail

    MOUNT="''${1:-/}"

    bold()   { printf '\033[1m%s\033[0m' "$1"; }
    dim()    { printf '\033[2m%s\033[0m' "$1"; }
    green()  { printf '\033[0;32m%s\033[0m' "$1"; }
    yellow() { printf '\033[0;33m%s\033[0m' "$1"; }
    red()    { printf '\033[0;31m%s\033[0m' "$1"; }

    bytes_to_human() {
      local b=$1
      if   (( b >= 1000000000000 )); then printf "%.1f GB" "$(echo "$b / 1000000000" | bc -l)"
      elif (( b >= 1000000000 ));    then printf "%.1f GB" "$(echo "$b / 1000000000" | bc -l)"
      elif (( b >= 1000000 ));       then printf "%.1f MB" "$(echo "$b / 1000000" | bc -l)"
      elif (( b >= 1000 ));          then printf "%.1f KB" "$(echo "$b / 1000" | bc -l)"
      else printf "%d B" "$b"
      fi
    }

    pct() {
      local part=$1 whole=$2
      if (( whole == 0 )); then echo "0.0"; return; fi
      printf "%.1f" "$(echo "$part * 100 / $whole" | bc -l)"
    }

    bar() {
      local pct_val=$1 width=40
      local filled=$(echo "$pct_val * $width / 100" | bc -l | awk '{printf "%d", $1}')
      local empty=$((width - filled))
      local color="\033[0;32m"
      if (( $(echo "$pct_val > 80" | bc -l) )); then color="\033[0;31m";
      elif (( $(echo "$pct_val > 60" | bc -l) )); then color="\033[0;33m"; fi
      printf "''${color}"
      printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
      printf "\033[2m"
      printf '%0.s░' $(seq 1 $empty 2>/dev/null) || true
      printf "\033[0m"
    }

    DEVICE=$(df "$MOUNT" 2>/dev/null | tail -1 | awk '{print $1}')
    if [ -z "$DEVICE" ]; then
      echo "Could not determine device for $MOUNT"
      exit 1
    fi

    CONTAINER=$(echo "$DEVICE" | sed 's|/dev/||; s/s[0-9]*$//' | sed 's/s[0-9]*$//')

    CONTAINER_INFO=$(diskutil apfs list "$CONTAINER" 2>/dev/null)
    CONTAINER_TOTAL=$(echo "$CONTAINER_INFO" | grep "Capacity Ceiling" | grep -oE '[0-9]+ B' | awk '{print $1}')
    CONTAINER_FREE=$(echo "$CONTAINER_INFO" | grep "Not Allocated" | grep -oE '[0-9]+ B' | awk '{print $1}')
    CONTAINER_USED=$((CONTAINER_TOTAL - CONTAINER_FREE))

    declare -a VOL_NAMES=()
    declare -a VOL_SIZES=()
    declare -a VOL_ROLES=()

    while IFS= read -r line; do
      if echo "$line" | grep -q "APFS Volume Disk (Role)"; then
        role=$(echo "$line" | sed 's/.*(\(.*\))/\1/')
        VOL_ROLES+=("$role")
      elif echo "$line" | grep -q "Name:"; then
        name=$(echo "$line" | sed 's/.*Name:[[:space:]]*//' | sed 's/ (.*)//')
        VOL_NAMES+=("$name")
      elif echo "$line" | grep -q "Capacity Consumed:"; then
        size=$(echo "$line" | grep -oE '[0-9]+ B' | head -1 | awk '{print $1}')
        VOL_SIZES+=("$size")
      fi
    done < <(echo "$CONTAINER_INFO" | grep -E "APFS Volume Disk|Name:|Capacity Consumed:")

    DATA_DISK=""
    for i in "''${!VOL_ROLES[@]}"; do
      if [ "''${VOL_ROLES[$i]}" = "Data" ]; then
        DATA_DISK="''${CONTAINER}s$((i + 1))"
        break
      fi
    done

    FINDER_AVAIL=$(osascript -e 'tell application "Finder" to get free space of startup disk' 2>/dev/null || echo "0")
    FINDER_AVAIL=$(printf "%.0f" "$FINDER_AVAIL")

    PURGEABLE=$((FINDER_AVAIL - CONTAINER_FREE))
    if (( PURGEABLE < 0 )); then PURGEABLE=0; fi

    VOL_SUM=0
    for s in "''${VOL_SIZES[@]}"; do
      VOL_SUM=$((VOL_SUM + s))
    done
    SNAPSHOT_SPACE=$((CONTAINER_USED - VOL_SUM))
    if (( SNAPSHOT_SPACE < 0 )); then SNAPSHOT_SPACE=0; fi

    DATA_VOL="''${CONTAINER}s5"
    # grep -c prints 0 on no match but exits 1 — use `|| true`, not `|| echo 0` (which would double the 0)
    SNAPSHOT_COUNT=$(diskutil apfs listSnapshots "$DATA_VOL" 2>/dev/null | grep -c "com.apple.TimeMachine" || true)
    SNAPSHOT_LIST=$(tmutil listlocalsnapshotdates / 2>/dev/null | tail -n +2 || true)
    OLDEST_SNAP=$(echo "$SNAPSHOT_LIST" | head -1)
    NEWEST_SNAP=$(echo "$SNAPSHOT_LIST" | tail -1)

    TRUE_AVAIL=$FINDER_AVAIL

    echo ""
    bold "APFS Disk Space — $(hostname)"; echo ""
    dim "Container: $CONTAINER ($DEVICE)"; echo ""
    echo ""

    USED_PCT=$(pct "$CONTAINER_USED" "$CONTAINER_TOTAL")
    printf "  "; bar "$USED_PCT"
    printf "  %s / %s (%s%%)\n" "$(bytes_to_human $CONTAINER_USED)" "$(bytes_to_human $CONTAINER_TOTAL)" "$USED_PCT"
    echo ""

    bold "  Volume Breakdown"; echo ""
    for i in "''${!VOL_NAMES[@]}"; do
      printf "    %-20s  %10s  (%s)\n" "''${VOL_NAMES[$i]}" "$(bytes_to_human ''${VOL_SIZES[$i]})" "''${VOL_ROLES[$i]}"
    done
    echo ""

    bold "  Free Space"; echo ""
    printf "    %-20s  %10s  %s\n" "Unallocated" "$(bytes_to_human $CONTAINER_FREE)" "$(dim "(df reports this)")"
    if (( PURGEABLE > 0 )); then
      printf "    %-20s  %10s  %s\n" "+ Purgeable" "$(bytes_to_human $PURGEABLE)" "$(dim "(snapshots, iCloud, caches)")"
    fi
    printf "    %-20s  " "= True Available"
    green "$(bytes_to_human $TRUE_AVAIL)"; echo " $(dim "(Finder reports this)")"
    echo ""

    bold "  Time Machine Local Snapshots"; echo ""
    if (( SNAPSHOT_COUNT > 0 )); then
      printf "    Count:     %d\n" "$SNAPSHOT_COUNT"
      printf "    Overhead:  %s\n" "$(bytes_to_human $SNAPSHOT_SPACE)"
      if [ -n "$OLDEST_SNAP" ]; then
        printf "    Oldest:    %s\n" "$OLDEST_SNAP"
        printf "    Newest:    %s\n" "$NEWEST_SNAP"
      fi
      dim "    (delete all: sudo tmutil deletelocalsnapshots /)"; echo ""
      dim "    (delete one: sudo tmutil deletelocalsnapshots <date>)"; echo ""
    else
      printf "    None\n"
    fi
    echo ""

    SMART=$(diskutil info "$DEVICE" 2>/dev/null | grep "SMART Status" | awk '{print $NF}')
    if [ -n "$SMART" ]; then
      printf "  SMART: "
      if [ "$SMART" = "Verified" ]; then green "$SMART"; else red "$SMART"; fi
      echo ""
    fi

    echo ""
  '';
in
{
  environment.systemPackages = [
    projectCleanup
    cacheCleanup
    diskspace
    (pkgs.writeShellScriptBin "projects-cleanup" ''
      exec ${projectCleanup}/bin/project-cleanup "$@"
    '')
    (pkgs.writeShellScriptBin "diskspace-usage" ''
      exec ${diskspace}/bin/diskspace "$@"
    '')
  ];
}
