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
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, --test    Run in test mode (dry-activate)"
            echo "  --sequential         Deploy hosts one at a time (default: parallel)"
            echo "  --max-jobs N         Limit parallel deployments to N hosts (0=unlimited)"
            echo "  --quiet, -q          Suppress deployment output (show only status)"
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

# Combine all hosts
ALL_HOSTS=$(echo -e "$NIXOS_HOSTS\n$DARWIN_HOSTS" | sort -u | grep -v '^$' || true)

# Debug output
if [ "${DEBUG:-false}" = "true" ]; then
    echo "DEBUG: NIXOS_HOSTS='$NIXOS_HOSTS'"
    echo "DEBUG: DARWIN_HOSTS='$DARWIN_HOSTS'"
    echo "DEBUG: ALL_HOSTS='$ALL_HOSTS'"
fi

if [ -z "$ALL_HOSTS" ]; then
    echo -e "${RED}No hosts found!${NC}"
    echo -e "${YELLOW}Tip: Make sure you're in the nixos configuration directory.${NC}"
    echo -e "${YELLOW}Current directory: $(pwd)${NC}"
    exit 1
fi

# Count hosts
TOTAL_HOSTS=$(echo "$ALL_HOSTS" | wc -l | tr -d ' ')

echo -e "${GREEN}Found $TOTAL_HOSTS hosts:${NC}"
echo "$ALL_HOSTS" | sed 's/^/  - /'
echo ""

# Create temporary directory for logs
LOG_DIR=$(mktemp -d)
trap "rm -rf $LOG_DIR" EXIT

# Function to deploy a single host
deploy_host() {
    local host=$1
    local log_file="$LOG_DIR/${host}.log"
    local start_time=$(date +%s)
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] Starting deployment to ${host}...${NC}"
    
    # Get current hostname
    local HOSTNAME=$(hostname -s | tr '[:upper:]' '[:lower:]')
    local HOST_LOWER=$(echo "$host" | tr '[:upper:]' '[:lower:]')
    
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
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ ${host} deployed successfully (${duration}s)${NC}"
        echo "SUCCESS:${duration}" > "${log_file}.status"
    else
        local end_time=$(date +%s)
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
echo -e "${BLUE}                 DEPLOYMENT REPORT                      ${NC}"
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
            ((SUCCESS_COUNT++))
        else
            ((FAILED_COUNT++))
            FAILED_HOSTS="${FAILED_HOSTS}${host}\n"
        fi
    else
        ((FAILED_COUNT++))
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
    
    echo ""
    echo -e "${YELLOW}Note: Log files will be deleted when this script exits.${NC}"
    echo -e "${YELLOW}Press Ctrl+C now if you want to preserve the logs.${NC}"
    read -n 1 -s -r -p "Press any key to continue and delete logs..."
    echo ""
fi

# Exit with appropriate code
if [ "$FAILED_COUNT" -gt 0 ]; then
    exit 1
else
    echo ""
    echo -e "${GREEN}All deployments completed successfully!${NC}"
    exit 0
fi