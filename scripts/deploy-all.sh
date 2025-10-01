#!/usr/bin/env bash
# Deploy to all hosts in parallel and generate a report

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

# Parse command line arguments
DRY_RUN=false
PARALLEL=true
MAX_JOBS=0  # 0 means unlimited
QUIET=false
SKIP_HOSTS=""
DARWIN_ONLY=false
LINUX_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|--test)
            DRY_RUN=true
            shift
            ;;
        --sequential)
            PARALLEL=false
            shift
            ;;
        --max-jobs)
            MAX_JOBS="$2"
            shift 2
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --skip)
            if [[ -z "${2:-}" ]] || [[ "$2" =~ ^-- ]]; then
                echo "Error: --skip requires a hostname or comma-separated list of hostnames"
                exit 1
            fi
            SKIP_HOSTS="$2"
            shift 2
            ;;
        --darwin-only)
            DARWIN_ONLY=true
            shift
            ;;
        --linux-only)
            LINUX_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, --test    Run in test mode (dry-activate)"
            echo "  --sequential         Deploy hosts one at a time (default: parallel)"
            echo "  --max-jobs N         Limit parallel deployments to N hosts (0=unlimited)"
            echo "  --quiet, -q          Suppress deployment output (show only status)"
            echo "  --skip HOSTS         Skip specified hosts (comma-separated list)"
            echo "  --darwin-only        Deploy only to Darwin (macOS) hosts"
            echo "  --linux-only         Deploy only to Linux (NixOS) hosts"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get all hosts from flake
echo -e "${BLUE}Discovering hosts...${NC}"

# Ensure we're in the flake directory
if [ ! -f "$FLAKE_DIR/flake.nix" ]; then
    echo -e "${RED}Error: flake.nix not found in $FLAKE_DIR${NC}"
    echo -e "${YELLOW}Please run this command from the nixos configuration directory${NC}"
    exit 1
fi

cd "$FLAKE_DIR"

# Get flake metadata
echo -e "${YELLOW}Loading flake metadata (this may take a moment)...${NC}"

# Try to get flake info, but don't let it hang forever
if command -v timeout >/dev/null 2>&1; then
    FLAKE_JSON=$(timeout 30 nix flake show --json 2>/dev/null) || FLAKE_JSON=""
else
    # No timeout command, just run it
    FLAKE_JSON=$(nix flake show --json 2>/dev/null) || FLAKE_JSON=""
fi

if [ -z "$FLAKE_JSON" ]; then
    echo -e "${YELLOW}Using alternative host discovery method...${NC}"
    # Alternative: list directories in hosts/
    if [ -d "hosts" ]; then
        NIXOS_HOSTS=$(find hosts -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -v -E '^(darkstarmk6mod1|halcyon|sevastopol)$' | sort)
        DARWIN_HOSTS=$(find hosts -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -E '^(darkstarmk6mod1|halcyon|sevastopol)$' | sort)
    else
        echo -e "${RED}Error: hosts directory not found. Are you in the nixos configuration directory?${NC}"
        exit 1
    fi
fi

if [ -n "$FLAKE_JSON" ]; then
    # Get NixOS hosts
    NIXOS_HOSTS=$(echo "$FLAKE_JSON" | jq -r '.nixosConfigurations | keys[]' 2>/dev/null | sort) || NIXOS_HOSTS=""
    
    # Get Darwin hosts - filter out "type" key which appears when darwinConfigurations is unevaluated
    DARWIN_HOSTS=$(echo "$FLAKE_JSON" | jq -r '.darwinConfigurations | keys[] | select(. != "type")' 2>/dev/null | sort) || DARWIN_HOSTS=""
    
    # If darwinConfigurations is completely unevaluated, fall back to known hosts
    if [ -z "$DARWIN_HOSTS" ] || [ "$DARWIN_HOSTS" = "type" ]; then
        # Known Darwin hosts based on the codebase
        DARWIN_HOSTS="darkstarmk6mod1
halcyon
sevastopol"
    fi
fi

# Check for conflicting options
if [ "$DARWIN_ONLY" = true ] && [ "$LINUX_ONLY" = true ]; then
    echo -e "${RED}Error: --darwin-only and --linux-only cannot be used together${NC}"
    exit 1
fi

# Filter hosts based on platform options
if [ "$DARWIN_ONLY" = true ]; then
    ALL_HOSTS="$DARWIN_HOSTS"
elif [ "$LINUX_ONLY" = true ]; then
    ALL_HOSTS="$NIXOS_HOSTS"
else
    # Combine all hosts
    ALL_HOSTS=$(echo -e "$NIXOS_HOSTS\n$DARWIN_HOSTS" | sort -u | grep -v '^$' || true)
fi

# Filter out skipped hosts
if [ -n "$SKIP_HOSTS" ]; then
    # Convert comma-separated list to newline-separated for easy grep
    SKIP_PATTERN=$(echo "$SKIP_HOSTS" | tr ',' '\n' | paste -sd '|' -)
    ALL_HOSTS=$(echo "$ALL_HOSTS" | grep -v -E "^($SKIP_PATTERN)$" || true)
fi

# Debug output
if [ "${DEBUG:-false}" = "true" ]; then
    echo "DEBUG: NIXOS_HOSTS='$NIXOS_HOSTS'"
    echo "DEBUG: DARWIN_HOSTS='$DARWIN_HOSTS'"
    echo "DEBUG: SKIP_HOSTS='$SKIP_HOSTS'"
    echo "DEBUG: ALL_HOSTS='$ALL_HOSTS'"
fi

if [ -z "$ALL_HOSTS" ]; then
    echo -e "${RED}No hosts found!${NC}"
    if [ -n "$SKIP_HOSTS" ]; then
        echo -e "${YELLOW}Note: You may have skipped all available hosts.${NC}"
    fi
    if [ "$DARWIN_ONLY" = true ]; then
        echo -e "${YELLOW}Note: No Darwin hosts found or all were skipped.${NC}"
    elif [ "$LINUX_ONLY" = true ]; then
        echo -e "${YELLOW}Note: No Linux hosts found or all were skipped.${NC}"
    else
        echo -e "${YELLOW}Tip: Make sure you're in the nixos configuration directory.${NC}"
        echo -e "${YELLOW}Current directory: $(pwd)${NC}"
    fi
    exit 1
fi

# Count hosts
TOTAL_HOSTS=$(echo "$ALL_HOSTS" | wc -l | tr -d ' ')

# Show filter status
FILTER_MSG=""
if [ "$DARWIN_ONLY" = true ]; then
    FILTER_MSG=" (Darwin hosts only)"
elif [ "$LINUX_ONLY" = true ]; then
    FILTER_MSG=" (Linux hosts only)"
fi
if [ -n "$SKIP_HOSTS" ]; then
    FILTER_MSG="${FILTER_MSG} [skipping: $SKIP_HOSTS]"
fi

echo -e "${GREEN}Found $TOTAL_HOSTS hosts${FILTER_MSG}:${NC}"
# shellcheck disable=SC2001
echo "$ALL_HOSTS" | sed 's/^/  - /'
echo ""

# Create directory for logs with timestamp
LOG_DIR="/tmp/nixos-deploy-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
# No trap to delete logs - they will persist

# Function to deploy a single host
deploy_host() {
    local host=$1
    local log_file="$LOG_DIR/${host}.log"
    local start_time
    start_time=$(date +%s)
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] Starting deployment to ${host}...${NC}"
    
    # Get current hostname
    local HOSTNAME
    HOSTNAME=$(hostname -s | tr '[:upper:]' '[:lower:]')
    local HOST_LOWER
    HOST_LOWER=$(echo "$host" | tr '[:upper:]' '[:lower:]')
    
    # Prepare deployment directory
    local TEMP_DIR=""
    local deploy_cmd=""
    
    # Check if this is the local host
    if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
        # Local deployment
        echo "[Local deployment]" >> "$log_file"
        
        if echo "$DARWIN_HOSTS" | grep -q "^${host}$"; then
            # Darwin local deployment
            TEMP_DIR="/private/tmp/nixos-config"
            rm -rf "$TEMP_DIR" 2>/dev/null || true
            mkdir -p "$TEMP_DIR"
            rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' "$FLAKE_DIR/" "$TEMP_DIR/" >> "$log_file" 2>&1
            
            if [ "$DRY_RUN" = true ]; then
                deploy_cmd="cd $TEMP_DIR && NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.$host.system --impure"
            else
                deploy_cmd="sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake $TEMP_DIR#$host --impure --no-update-lock-file"
            fi
        else
            # NixOS local deployment
            TEMP_DIR="/tmp/nixos-config"
            rm -rf "$TEMP_DIR" 2>/dev/null || true
            mkdir -p "$TEMP_DIR"
            rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' "$FLAKE_DIR/" "$TEMP_DIR/" >> "$log_file" 2>&1

            # Special handling for hal9000 PixInsight package
            if [ "$HOST_LOWER" = "hal9000" ]; then
                echo "Checking for PixInsight tarball cache..." >> "$log_file"
                PIXINSIGHT_CACHE="/var/cache/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz"
                if [ -f "$PIXINSIGHT_CACHE" ]; then
                    echo "Found PixInsight tarball in cache, adding to nix store with GC root..." >> "$log_file"
                    STORE_PATH=$(sudo nix-store --add-fixed sha256 "$PIXINSIGHT_CACHE" 2>&1 | grep -v "warning:" || true)
                    if [ -n "$STORE_PATH" ]; then
                        # Create GC root to prevent garbage collection
                        sudo mkdir -p /nix/var/nix/gcroots/pixinsight >> "$log_file" 2>&1
                        sudo ln -sf "$STORE_PATH" /nix/var/nix/gcroots/pixinsight/tarball >> "$log_file" 2>&1 || true
                        echo "Created GC root to protect PixInsight from garbage collection" >> "$log_file"
                    fi
                else
                    echo "Warning: PixInsight tarball not found at $PIXINSIGHT_CACHE" >> "$log_file"
                fi
            fi

            if [ "$DRY_RUN" = true ]; then
                deploy_cmd="sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake $TEMP_DIR#$host --impure"
            else
                deploy_cmd="sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake $TEMP_DIR#$host --verbose --impure"
            fi
        fi
    else
        # Remote deployment
        echo "[Remote deployment]" >> "$log_file"
        
        if echo "$DARWIN_HOSTS" | grep -q "^${host}$"; then
            # Darwin remote deployment
            TEMP_DIR="/private/tmp/nixos-config"
            rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' "$FLAKE_DIR/" "jamesbrink@$host:$TEMP_DIR/" >> "$log_file" 2>&1
            
            if [ "$DRY_RUN" = true ]; then
                deploy_cmd="ssh jamesbrink@$host 'cd $TEMP_DIR && NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.$host.system --impure'"
            else
                deploy_cmd="ssh jamesbrink@$host 'sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake $TEMP_DIR#$host --impure --no-update-lock-file'"
            fi
        else
            # NixOS remote deployment
            TEMP_DIR="/tmp/nixos-config"
            rsync -avz --exclude '.git' --exclude '.gitignore' --exclude '.gitmodules' --exclude 'result' "$FLAKE_DIR/" "root@$host:$TEMP_DIR/" >> "$log_file" 2>&1

            # Special handling for hal9000 PixInsight package
            if [ "$HOST_LOWER" = "hal9000" ]; then
                echo "Checking for PixInsight tarball cache on hal9000..." >> "$log_file"
                ssh root@"$host" 'bash -s' >> "$log_file" 2>&1 << 'ENDSSH'
                    PIXINSIGHT_CACHE="/var/cache/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz"
                    if [ -f "$PIXINSIGHT_CACHE" ]; then
                        echo "Found PixInsight tarball in cache, adding to nix store with GC root..."
                        STORE_PATH=$(nix-store --add-fixed sha256 "$PIXINSIGHT_CACHE" 2>&1 | grep -v "warning:" || true)
                        if [ -n "$STORE_PATH" ]; then
                            # Create GC root to prevent garbage collection
                            mkdir -p /nix/var/nix/gcroots/pixinsight
                            ln -sf "$STORE_PATH" /nix/var/nix/gcroots/pixinsight/tarball || true
                            echo "Created GC root to protect PixInsight from garbage collection"
                        fi
                    else
                        echo "Warning: PixInsight tarball not found at $PIXINSIGHT_CACHE"
                    fi
ENDSSH
            fi

            if [ "$DRY_RUN" = true ]; then
                deploy_cmd="ssh root@$host 'cd $TEMP_DIR && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$host --impure'"
            else
                deploy_cmd="ssh root@$host 'NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake $TEMP_DIR#$host --verbose --impure'"
            fi
        fi
    fi
    
    # Run deployment
    echo "Running: $deploy_cmd" >> "$log_file"
    if eval "$deploy_cmd" >> "$log_file" 2>&1; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} deployed successfully (${duration}s)${NC}"
        echo "SUCCESS:${duration}" > "${log_file}.status"
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}[$(date +%H:%M:%S)] ✗ ${host} deployment failed (${duration}s)${NC}"
        echo "FAILED:${duration}" > "${log_file}.status"
        
        # Show last few lines of error only if not quiet
        if [ "$QUIET" = false ]; then
            echo -e "${YELLOW}Last 10 lines of error log:${NC}"
            tail -n 10 "$log_file" | sed 's/^/  /'
        fi
    fi
}

# Export the function so it can be used by parallel
export -f deploy_host
export DARWIN_HOSTS NIXOS_HOSTS DRY_RUN LOG_DIR QUIET FLAKE_DIR
export RED GREEN YELLOW BLUE NC

# Start deployments
echo -e "${BLUE}Starting deployments...${NC}"
START_TIME=$(date +%s)

if [ "$PARALLEL" = true ]; then
    if [ "$MAX_JOBS" -eq 0 ]; then
        echo -e "${YELLOW}Running all deployments in parallel${NC}"
    else
        echo -e "${YELLOW}Running deployments with max $MAX_JOBS parallel jobs${NC}"
    fi
    
    # Use GNU parallel if available, otherwise fall back to xargs
    if command -v parallel &> /dev/null; then
        echo "$ALL_HOSTS" | parallel -j "$MAX_JOBS" deploy_host {}
    else
        if [ "$MAX_JOBS" -eq 0 ]; then
            MAX_JOBS=$(nproc)
        fi
        echo "$ALL_HOSTS" | xargs -P "$MAX_JOBS" -I {} bash -c 'deploy_host "$@"' _ {}
    fi
else
    echo -e "${YELLOW}Running deployments sequentially${NC}"
    while IFS= read -r host; do
        deploy_host "$host"
    done <<< "$ALL_HOSTS"
fi

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# Generate report
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                 DEPLOYMENT REPORT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Count successes and failures
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_HOSTS=""

while IFS= read -r host; do
    if [ -f "$LOG_DIR/${host}.log.status" ]; then
        STATUS=$(cat "$LOG_DIR/${host}.log.status")
        if [[ $STATUS == SUCCESS:* ]]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_HOSTS="${FAILED_HOSTS}${host}\n"
        fi
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_HOSTS="${FAILED_HOSTS}${host} (no status)\n"
    fi
done <<< "$ALL_HOSTS"

# Summary
echo -e "Total hosts:      $TOTAL_HOSTS"
echo -e "Successful:       ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Failed:           ${RED}$FAILED_COUNT${NC}"
echo -e "Total duration:   ${TOTAL_DURATION}s"
echo -e "Mode:             $([ "$DRY_RUN" = true ] && echo "Dry-run" || echo "Live deployment")"
echo ""

# Per-host details
echo -e "${BLUE}Per-host results:${NC}"
echo -e "─────────────────────────────────────────────────────"
printf "%-20s %-10s %s\n" "HOST" "STATUS" "DURATION"
echo -e "─────────────────────────────────────────────────────"

while IFS= read -r host; do
    if [ -f "$LOG_DIR/${host}.log.status" ]; then
        STATUS_LINE=$(cat "$LOG_DIR/${host}.log.status")
        STATUS=$(echo "$STATUS_LINE" | cut -d: -f1)
        DURATION=$(echo "$STATUS_LINE" | cut -d: -f2)
        
        if [ "$STATUS" = "SUCCESS" ]; then
            printf "%-20s ${GREEN}%-10s${NC} %ss\n" "$host" "$STATUS" "$DURATION"
        else
            printf "%-20s ${RED}%-10s${NC} %ss\n" "$host" "$STATUS" "$DURATION"
        fi
    else
        printf "%-20s ${RED}%-10s${NC} -\n" "$host" "NO STATUS"
    fi
done <<< "$ALL_HOSTS" | sort

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Show failed hosts with log locations
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed hosts:${NC}"
    echo -e "$FAILED_HOSTS" | grep -v '^$' | while read -r host; do
        echo -e "  - $host"
        if [ -f "$LOG_DIR/${host}.log" ]; then
            echo -e "    Log: $LOG_DIR/${host}.log"
        fi
    done
fi

# Always show where logs are saved
echo ""
echo -e "${BLUE}Deployment logs saved in: ${LOG_DIR}${NC}"

# Exit with appropriate code
if [ "$FAILED_COUNT" -gt 0 ]; then
    exit 1
else
    echo ""
    echo -e "${GREEN}All deployments completed successfully!${NC}"
    exit 0
fi