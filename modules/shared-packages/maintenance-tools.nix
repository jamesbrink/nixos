# Cross-platform maintenance tools (NixOS + nix-darwin).
# Darwin-only tools (cache-cleanup, diskspace) live in modules/darwin/maintenance-tools.nix.
{ pkgs, lib, ... }:

let
  # bc is not installed on the Linux hosts; pin every runtime dep so the
  # script works from a bare PATH on both platforms.
  runtimeDeps = lib.makeBinPath (
    with pkgs;
    [
      bc
      coreutils
      findutils
      gawk
      gnused
    ]
  );

  projectCleanup = pkgs.writeShellScriptBin "project-cleanup" ''
    set -euo pipefail
    export PATH=${runtimeDeps}:$PATH

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
in
{
  environment.systemPackages = [
    projectCleanup
    (pkgs.writeShellScriptBin "projects-cleanup" ''
      exec ${projectCleanup}/bin/project-cleanup "$@"
    '')
  ];
}
