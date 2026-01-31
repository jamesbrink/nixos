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
        if sudo nix-collect-garbage -d 2>&1; then
            echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} GC complete${NC}"
            return 0
        else
            echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} GC failed${NC}"
            return 1
        fi
    else
        # Remote garbage collection
        # Check if host is darwin or linux by checking flake configuration
        if nix eval --json .#darwinConfigurations."$host"._type 2>/dev/null >/dev/null; then
            # Darwin host - use regular user with sudo
            if ssh jamesbrink@"$host" "sudo nix-collect-garbage -d" 2>&1; then
                echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} GC complete${NC}"
                return 0
            else
                echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} GC failed${NC}"
                return 1
            fi
        else
            # NixOS host - use root
            if ssh root@"$host" "nix-collect-garbage -d" 2>&1; then
                echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} GC complete${NC}"
                return 0
            else
                echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} GC failed${NC}"
                return 1
            fi
        fi
    fi
}

# Check for --all flag
if [ "${1:-}" = "--all" ]; then
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
    while IFS= read -r host; do echo "  - $host"; done <<< "$ALL_HOSTS"
    echo ""

    # Export function and variables for parallel execution
    export -f run_gc
    export RED GREEN YELLOW BLUE NC FLAKE_DIR

    echo -e "${BLUE}Starting garbage collection on all hosts in parallel...${NC}"
    START_TIME=$(date +%s)

    # Run GC on all hosts in parallel
    # Use GNU parallel if available, otherwise fall back to xargs
    if command -v parallel &> /dev/null; then
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
if [ $# -eq 0 ]; then
    HOST=""
else
    HOST="$1"
fi

if [ -z "$HOST" ]; then
    echo "Error: You must specify a hostname or use --all."
    echo "Usage: nix-gc <hostname>"
    echo "       nix-gc --all"
    echo ""
    echo "Available hosts:"
    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
    exit 1
fi

run_gc "$HOST"
