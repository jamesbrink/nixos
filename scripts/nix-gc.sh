#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script and the flake root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

# If we're in a devshell, PRJ_ROOT should be set
if [ -n "${PRJ_ROOT:-}" ]; then
    FLAKE_DIR="$PRJ_ROOT"
fi

OPTIMISE=0

usage() {
    echo "Usage: nix-gc [--optimise] <hostname>"
    echo "       nix-gc [--optimise] --all"
    echo ""
    echo "Collects Nix garbage on a host:"
    echo "  1. user-profile generations (nix-collect-garbage -d as the user)"
    echo "  2. system generations + store GC (sudo nix-collect-garbage -d)"
    echo "  3. stale eval caches (~/.cache/nix)"
    echo ""
    echo "Locally it also offers to remove result* symlinks under ~/Projects,"
    echo "which are GC roots pinning store closures (the usual reason a GC"
    echo "frees far less than expected)."
    echo ""
    echo "  --optimise   also hardlink-deduplicate the store (nix store optimise)"
}

# The GC sequence, shared by local and remote execution. User-level GC must
# run in addition to the sudo one: sudo only handles root/system profiles,
# while per-user and home-manager generations stay rooted otherwise.
gc_commands() {
    cat <<'EOF'
set -e
BEFORE=$(df -k /nix/store 2>/dev/null | tail -1 | awk '{print $4}')
nix-collect-garbage -d >/dev/null 2>&1 || true
rm -rf "$HOME/.cache/nix"
if [ "$(id -u)" = "0" ]; then
    nix-collect-garbage -d
else
    sudo nix-collect-garbage -d
fi
EOF
    if [ "$OPTIMISE" = 1 ]; then
        cat <<'EOF'
if [ "$(id -u)" = "0" ]; then
    nix store optimise
else
    sudo nix store optimise
fi
EOF
    fi
    cat <<'EOF'
AFTER=$(df -k /nix/store 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$BEFORE" ] && [ -n "$AFTER" ]; then
    echo "disk freed: $(((AFTER - BEFORE) / 1024)) MiB"
fi
EOF
}

# Offer to delete result* symlinks under ~/Projects. Each is a GC root that
# pins its whole build closure in the store; nix build recreates them on
# demand. Interactive-only so `nix-gc --all` stays non-blocking. .direnv GC
# roots are deliberately left alone — removing those forces devshell rebuilds.
prune_result_links() {
    if [ ! -t 0 ]; then
        return 0
    fi

    local links count
    links=$(find "$HOME/Projects" -maxdepth 5 -name 'result*' -type l -lname '/nix/store/*' 2>/dev/null || true)
    if [ -z "$links" ]; then
        return 0
    fi
    count=$(echo "$links" | wc -l | tr -d ' ')

    echo -e "${YELLOW}Found $count result* symlinks pinning store closures:${NC}"
    echo "$links" | sed "s|^$HOME|  ~|" | head -20
    if [ "$count" -gt 20 ]; then
        echo "  ... and $((count - 20)) more"
    fi
    read -rp "Delete them so this GC can reclaim their closures? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$links" | tr '\n' '\0' | xargs -0 rm -f
        echo -e "${GREEN}Removed $count GC roots${NC}"
    fi
    echo ""
}

# Function to run GC on a single host
run_gc() {
    local host=$1
    local HOSTNAME
    HOSTNAME=$(hostname -s | tr '[:upper:]' '[:lower:]')
    local HOST_LOWER
    HOST_LOWER=$(echo "$host" | tr '[:upper:]' '[:lower:]')

    echo -e "${BLUE}[$(date +%H:%M:%S)] Running garbage collection on ${host}...${NC}"

    if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
        # Local garbage collection
        prune_result_links
        if bash <(gc_commands) 2>&1; then
            echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} GC complete${NC}"
            return 0
        else
            echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} GC failed${NC}"
            return 1
        fi
    else
        # Remote garbage collection
        # Check if host is darwin or linux by checking flake configuration
        local ssh_target
        if nix eval --json .#darwinConfigurations."$host"._type 2>/dev/null >/dev/null; then
            # Darwin host - regular user runs its own GC, then sudo for the system
            ssh_target="jamesbrink@$host"
        else
            # NixOS host - root handles system; also GC jamesbrink's user profiles
            ssh_target="root@$host"
        fi
        if gc_commands | ssh "$ssh_target" "if [ \"\$(id -u)\" = 0 ] && id jamesbrink >/dev/null 2>&1; then su - jamesbrink -c 'nix-collect-garbage -d >/dev/null 2>&1; rm -rf ~/.cache/nix' || true; fi; bash -s" 2>&1; then
            echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} GC complete${NC}"
            return 0
        else
            echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} GC failed${NC}"
            return 1
        fi
    fi
}

# Parse flags
ALL=0
HOST=""
for arg in "$@"; do
    case "$arg" in
        --optimise | --optimize) OPTIMISE=1 ;;
        --all) ALL=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) HOST="$arg" ;;
    esac
done

if [ "$ALL" = 1 ]; then
    echo -e "${BLUE}Discovering hosts...${NC}"

    cd "$FLAKE_DIR"

    # Get flake metadata
    if command -v timeout >/dev/null 2>&1; then
        FLAKE_JSON=$(timeout 30 nix flake show --json 2>/dev/null) || FLAKE_JSON=""
    else
        FLAKE_JSON=$(nix flake show --json 2>/dev/null) || FLAKE_JSON=""
    fi

    if [ -z "$FLAKE_JSON" ]; then
        echo -e "${YELLOW}Using alternative host discovery method...${NC}"
        if [ -d "hosts" ]; then
            NIXOS_HOSTS=$(find hosts -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -v -E '^(halcyon|bender)$' | sort)
            DARWIN_HOSTS=$(find hosts -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -E '^(halcyon|bender)$' | sort)
        else
            echo -e "${RED}Error: hosts directory not found${NC}"
            exit 1
        fi
    else
        NIXOS_HOSTS=$(echo "$FLAKE_JSON" | jq -r '.nixosConfigurations | keys[]' 2>/dev/null | sort) || NIXOS_HOSTS=""
        DARWIN_HOSTS=$(echo "$FLAKE_JSON" | jq -r '.darwinConfigurations | keys[] | select(. != "type")' 2>/dev/null | sort) || DARWIN_HOSTS=""
        if [ -z "$DARWIN_HOSTS" ] || [ "$DARWIN_HOSTS" = "type" ]; then
            DARWIN_HOSTS=$(printf '%s\n' halcyon bender)
        fi
    fi

    ALL_HOSTS=$(echo -e "$NIXOS_HOSTS\n$DARWIN_HOSTS" | sort -u | grep -v '^$' || true)

    if [ -z "$ALL_HOSTS" ]; then
        echo -e "${RED}No hosts found!${NC}"
        exit 1
    fi

    TOTAL_HOSTS=$(echo "$ALL_HOSTS" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $TOTAL_HOSTS hosts:${NC}"
    while IFS= read -r host; do echo "  - $host"; done <<<"$ALL_HOSTS"
    echo ""

    # Export functions and variables for parallel execution
    export -f run_gc gc_commands prune_result_links
    export RED GREEN YELLOW BLUE NC FLAKE_DIR OPTIMISE

    echo -e "${BLUE}Starting garbage collection on all hosts in parallel...${NC}"
    START_TIME=$(date +%s)

    # Run GC on all hosts in parallel
    # Use GNU parallel if available, otherwise fall back to xargs
    if command -v parallel &>/dev/null; then
        echo "$ALL_HOSTS" | parallel --jobs 0 --tag run_gc {} || true
    else
        echo "$ALL_HOSTS" | xargs -P 0 -I {} bash -c 'run_gc "$@"' _ {} || true
    fi

    END_TIME=$(date +%s)
    TOTAL_DURATION=$((END_TIME - START_TIME))

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           GARBAGE COLLECTION COMPLETE${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "Total hosts:      $TOTAL_HOSTS"
    echo -e "Total duration:   ${TOTAL_DURATION}s"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

    exit 0
fi

# Single host mode
if [ -z "$HOST" ]; then
    echo "Error: You must specify a hostname or use --all."
    usage
    echo ""
    echo "Available hosts:"
    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
    exit 1
fi

run_gc "$HOST"
