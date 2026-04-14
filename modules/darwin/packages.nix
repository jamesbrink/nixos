{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      # Core utilities
      coreutils
      findutils
      gnugrep
      gnused
      gawk

      # Development tools
      git
      gh
      direnv

      # System tools
      htop
      btop
      duf

      # Note: ncdu and other disk usage analyzers are in modules/home-manager/cli-tools.nix
    ]
    ++ [
      # Network tools
      wget
      curl
      nmap

      # File management
      ripgrep
      fd
      bat
      eza
      tree

      # Text processing
      jq
      yq

      # Archive tools
      unzip
      p7zip

      # Security tools
      age

      # macOS specific
      mas # Mac App Store CLI
      dockutil
      grandperspective # Visual disk usage analyzer for macOS
      macmon # Sudoless performance monitoring for Apple Silicon

      # From unstable
      pkgs.unstablePkgs.atuin

      # Custom macOS utilities
      (writeShellScriptBin "project-cleanup" ''
        set -euo pipefail

        TARGET="''${1:-$HOME/Projects}"
        TOTAL_FREED=0

        red()    { printf '\033[0;31m%s\033[0m' "$1"; }
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

        # Rust target/ directories
        while IFS= read -r cargo_file; do
          dir="$(dirname "$cargo_file")"
          target_dir="$dir/target"
          if [ -d "$target_dir" ]; then
            size=$(get_size_bytes "$target_dir")
            TARGETS+=("rust|$dir|$size")
          fi
        done < <(find "$TARGET" -maxdepth 5 -name Cargo.toml -type f 2>/dev/null)

        # node_modules
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("node|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name node_modules -type d -not -path "*/node_modules/*/node_modules" 2>/dev/null)

        # .next build caches
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("next|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name ".next" -type d 2>/dev/null)

        # .turbo caches
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("turbo|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name ".turbo" -type d 2>/dev/null)

        # .parcel-cache
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("parcel|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name ".parcel-cache" -type d 2>/dev/null)

        # Python caches
        for pattern in __pycache__ .pytest_cache .mypy_cache .ruff_cache; do
          while IFS= read -r d; do
            size=$(get_size_bytes "$d")
            TARGETS+=("python|$d|$size")
          done < <(find "$TARGET" -maxdepth 6 -name "$pattern" -type d 2>/dev/null)
        done
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("python|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name "*.egg-info" -type d 2>/dev/null)

        # Go build cache
        while IFS= read -r go_file; do
          dir="$(dirname "$go_file")"
          for sub in vendor .cache; do
            if [ -d "$dir/$sub" ]; then
              size=$(get_size_bytes "$dir/$sub")
              TARGETS+=("go|$dir/$sub|$size")
            fi
          done
        done < <(find "$TARGET" -maxdepth 4 -name go.mod -type f 2>/dev/null)

        # .direnv (nix dev shell profiles)
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("direnv|$d|$size")
        done < <(find "$TARGET" -maxdepth 4 -name ".direnv" -type d 2>/dev/null)

        # Swift .build directories (SPM)
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("swift|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name ".build" -type d -execdir test -e Package.swift \; -print 2>/dev/null)

        # Swift .swiftpm caches
        while IFS= read -r d; do
          size=$(get_size_bytes "$d")
          TARGETS+=("swift|$d|$size")
        done < <(find "$TARGET" -maxdepth 5 -name ".swiftpm" -type d 2>/dev/null)

        # Xcode DerivedData
        XCODE_DD="$HOME/Library/Developer/Xcode/DerivedData"
        if [ -d "$XCODE_DD" ]; then
          size=$(get_size_bytes "$XCODE_DD")
          if (( size > 0 )); then
            TARGETS+=("xcode|$XCODE_DD|$size")
          fi
        fi

        if [ ''${#TARGETS[@]} -eq 0 ]; then
          echo "No caches found."
          exit 0
        fi

        IFS=$'\n' SORTED=($(for t in "''${TARGETS[@]}"; do echo "$t"; done | sort -t'|' -k3 -rn))
        unset IFS

        echo "Found ''${#SORTED[@]} cache directories:"
        echo ""
        printf "  %-8s  %-10s  %s\n" "TYPE" "SIZE" "PATH"
        printf "  %-8s  %-10s  %s\n" "--------" "----------" "----"

        for entry in "''${SORTED[@]}"; do
          IFS='|' read -r type path size <<< "$entry"
          human=$(bytes_to_human "$size")
          rel="''${path#$TARGET/}"
          printf "  %-8s  %-10s  %s\n" "$type" "$human" "$rel"
          TOTAL_FREED=$((TOTAL_FREED + size))
        done

        echo ""
        echo "Total reclaimable: $(bold "$(bytes_to_human $TOTAL_FREED)")"
        echo ""

        read -rp "Remove all? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
          echo "Aborted."
          exit 0
        fi

        echo ""
        for entry in "''${SORTED[@]}"; do
          IFS='|' read -r type path size <<< "$entry"
          human=$(bytes_to_human "$size")
          rel="''${path#$TARGET/}"

          if [ "$type" = "rust" ]; then
            echo "  cargo clean: $rel"
            (cd "$path" && cargo clean 2>/dev/null) || rm -rf "$path/target"
          elif [ "$type" = "xcode" ]; then
            echo "  rm -rf: ~/Library/Developer/Xcode/DerivedData"
            rm -rf "$path"
          else
            echo "  rm -rf: $rel"
            rm -rf "$path"
          fi
        done

        echo ""
        green "Done."; echo " Freed ~$(bytes_to_human $TOTAL_FREED)"
        echo ""
      '')

      (writeShellScriptBin "diskspace" ''
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
        SNAPSHOT_COUNT=$(diskutil apfs listSnapshots "$DATA_VOL" 2>/dev/null | grep -c "com.apple.TimeMachine" || echo "0")
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
      '')
    ];
}
