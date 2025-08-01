# A package for managing PostgreSQL 13 database resets using ZFS snapshots
{
  pkgs,
  lib ? pkgs.lib,
}:

let
  # Create the rollback script for PostgreSQL 13
  postgres13-rollback = pkgs.writeScriptBin "postgres13-rollback" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "Killing PostgreSQL 13 service..."
     ${pkgs.systemd}/bin/systemctl kill -s KILL podman-postgres13.service || true

    echo "Removing PostgreSQL 13 container..."
     ${pkgs.podman}/bin/podman rm -f postgres13 || true
    echo "Container killed and removed"

    # Brief wait for filesystem to unmount
    sleep 2

    # Try to unmount if still mounted
    if mountpoint -q /storage-fast/quantierra/postgres13 2>/dev/null; then
      echo "Force unmounting postgres13 dataset..."
       umount -f /storage-fast/quantierra/postgres13 || true
      sleep 1
    fi

    # Destroy the existing clone with retries
    echo "Destroying existing dev clone..."
    for i in {1..3}; do
      if  ${pkgs.zfs}/bin/zfs destroy -rf storage-fast/quantierra/postgres13 2>/dev/null; then
        echo "Successfully destroyed postgres13 dataset"
        break
      else
        if [ $i -eq 3 ]; then
          echo "Warning: Could not destroy dataset after 3 attempts, forcing..."
          # Last resort - try to force destroy
           ${pkgs.zfs}/bin/zfs destroy -Rf storage-fast/quantierra/postgres13 || true
        else
          echo "Dataset busy, retry $i/3 in 2 seconds..."
          sleep 2
        fi
      fi
    done

    # Find the most recent base snapshot on the base dataset
    echo "Finding most recent base snapshot..."
    LATEST_BASE=$( ${pkgs.zfs}/bin/zfs list -t snapshot -o name -s creation | \
      grep "storage-fast/quantierra/base@base-" | \
      tail -1 || echo "")

    # Fallback to the original base if no base snapshots exist
    if [ -z "$LATEST_BASE" ]; then
      echo "No base snapshots found, using original backup"
      LATEST_BASE="storage-fast/quantierra/base@backup_20250727"
    fi

    echo "Creating new clone from $LATEST_BASE..."
     ${pkgs.zfs}/bin/zfs clone "$LATEST_BASE" storage-fast/quantierra/postgres13

    # Always add standby.signal for reset operation
     touch /storage-fast/quantierra/postgres13/standby.signal

    # Start the service back up (use restart to ensure standby.signal is recognized)
    echo "Starting podman-postgres13 service..."
     ${pkgs.systemd}/bin/systemctl restart podman-postgres13.service

    echo "Reset complete! PostgreSQL is in standby mode."
    echo "Source snapshot: $LATEST_BASE"
  '';

  # Create the activate script for PostgreSQL 13
  postgres13-activate = pkgs.writeScriptBin "postgres13-activate" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "=== Switching PostgreSQL to Development Mode ==="

    # Check if container is running
    if !  ${pkgs.podman}/bin/podman ps | grep -q postgres13; then
      echo "Error: postgres13 container is not running"
      echo "Starting container first..."
       ${pkgs.systemd}/bin/systemctl start podman-postgres13.service
      sleep 5
    fi

    # Check current recovery status
    RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ' || echo "error")

    if [ "$RECOVERY_STATUS" = "f" ]; then
      echo "PostgreSQL is already in normal (read-write) mode"
      exit 0
    fi

    echo "PostgreSQL is currently in recovery mode"
    echo "Removing standby.signal to switch to normal mode..."

    # Remove standby signal file
     rm -f /storage-fast/quantierra/postgres13/standby.signal

    # Restart the container to apply changes
    echo "Restarting PostgreSQL container..."
     ${pkgs.systemd}/bin/systemctl restart podman-postgres13.service

    # Wait for container to be ready
    echo "Waiting for PostgreSQL to start..."
    sleep 5

    # Verify the mode change - wait up to 5 minutes for recovery
    echo "PostgreSQL is performing recovery. This may take several minutes..."
    for i in {1..60}; do
      # Check if we can connect
      if  ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -c "SELECT 1;" &>/dev/null; then
        RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ')
        if [ "$RECOVERY_STATUS" = "f" ]; then
          echo "✓ PostgreSQL is now in normal (read-write) mode"
          echo "✓ Development mode enabled successfully"
          exit 0
        fi
      else
        # Check logs for recovery progress
        if [ $((i % 10)) -eq 0 ]; then
          echo "Still recovering... checking logs:"
           ${pkgs.podman}/bin/podman logs --tail 5 postgres13 | grep -E "(redo|recovery|consistent)" || true
        fi
      fi
      echo -ne "Waiting for PostgreSQL to be ready... ($i/60)\r"
      sleep 5
    done

    echo ""
    echo "Error: PostgreSQL failed to start within 5 minutes"
    echo "Recent logs:"
     ${pkgs.podman}/bin/podman logs --tail 20 postgres13
    exit 1
  '';

  # Create base snapshot management script
  postgres13-create-base = pkgs.writeScriptBin "postgres13-create-base" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "=== Creating New Base Snapshot ==="

    # Check if PostgreSQL is in recovery mode
    RECOVERY_STATUS=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT pg_is_in_recovery();" | tr -d ' ' || echo "error")

    if [ "$RECOVERY_STATUS" != "t" ]; then
      echo "Warning: PostgreSQL is not in recovery mode. Base snapshots should be created from a consistent standby state."
      read -p "Continue anyway? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
    fi

    # Check replication lag
    LAG_INFO=$( ${pkgs.podman}/bin/podman exec postgres13 psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int ELSE 0 END as lag_seconds;" | tr -d ' ')

    if [ "$LAG_INFO" -gt 300 ]; then
      echo "Warning: Replication lag is $LAG_INFO seconds (> 5 minutes)"
      read -p "Continue anyway? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
    fi

    # Create the base snapshot on the base dataset
    SNAPSHOT_NAME="base@base-$(date +%Y%m%d)"
    echo "Creating base snapshot: $SNAPSHOT_NAME"
     ${pkgs.zfs}/bin/zfs snapshot "storage-fast/quantierra/$SNAPSHOT_NAME"

    # Clean up old base snapshots (keep last 3)
    echo "Cleaning up old base snapshots..."
     ${pkgs.zfs}/bin/zfs list -t snapshot -o name -s creation | \
      grep "storage-fast/quantierra/base@base-" | \
      head -n -3 | \
      xargs -r -n1  ${pkgs.zfs}/bin/zfs destroy || true

    # List remaining base snapshots
    echo ""
    echo "Current base snapshots:"
     ${pkgs.zfs}/bin/zfs list -t snapshot -o name,creation | grep "base@base-" || echo "None found"

    echo ""
    echo "Base snapshot created successfully!"
  '';

  # Create the rollback script for PostgreSQL 17
  postgres17-rollback = pkgs.writeScriptBin "postgres17-rollback" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "Killing PostgreSQL 17 container..."
    ${pkgs.podman}/bin/podman kill postgres17 || true
    echo "Container killed"

    # Roll back to the upgrade-complete snapshot
    echo "Rolling back to pg17-upgrade-complete snapshot..."
    ${pkgs.zfs}/bin/zfs rollback storage-fast/quantierra/postgres13-17@pg17-upgrade-complete

    # Start the service back up
    echo "Starting podman-postgres17 service..."
    ${pkgs.systemd}/bin/systemctl start podman-postgres17.service

    echo "Reset complete!"
  '';

  # Create the webhook handler script
  webhook-handler = pkgs.writeScriptBin "webhook-postgres-reset" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    # Get the token from the first argument
    TOKEN="$1"

    case "$TOKEN" in
      "WEBHOOK_TOKEN_RESET"|"reset")
        echo "PostgreSQL 13 rollback initiated"
        ${postgres13-rollback}/bin/postgres13-rollback
        echo "PostgreSQL 13 rollback completed"
        ;;
      "WEBHOOK_TOKEN_ACTIVE"|"active")
        echo "PostgreSQL 13 activate initiated"
        ${postgres13-activate}/bin/postgres13-activate
        echo "PostgreSQL 13 activation completed"
        ;;
      "WEBHOOK_TOKEN_RESET17"|"reset17")
        echo "PostgreSQL 17 rollback initiated"
        ${postgres17-rollback}/bin/postgres17-rollback
        echo "PostgreSQL 17 rollback completed"
        ;;
      *)
        echo "Invalid token: $TOKEN"
        exit 1
        ;;
    esac
  '';

  # Helper command to trigger reset webhook
  postgres13-reset = pkgs.writeScriptBin "postgres13-reset" ''
    #!${pkgs.bash}/bin/bash
    echo "Triggering PostgreSQL 13 reset webhook..."
    response=$(${pkgs.curl}/bin/curl -s -X POST -H "X-Webhook-Token: WEBHOOK_TOKEN_RESET" http://localhost:9000/hooks/postgres-rollback)
    echo "$response"
  '';

  # Helper command to trigger activate webhook
  postgres13-activate-cmd = pkgs.writeScriptBin "postgres13-activate" ''
    #!${pkgs.bash}/bin/bash
    echo "Triggering PostgreSQL 13 activate webhook..."
    response=$(${pkgs.curl}/bin/curl -s -X POST -H "X-Webhook-Token: WEBHOOK_TOKEN_ACTIVE" http://localhost:9000/hooks/postgres-rollback)
    echo "$response"
  '';

  # Webhook configuration template
  # Note: The actual tokens should be provided via environment variables or secrets
  webhookConfig = ''
    [{
      "id": "postgres-rollback",
      "trigger-rule": {
        "or": [
          {
            "match": {
              "type": "value",
              "value": "WEBHOOK_TOKEN_RESET",
              "parameter": {
                "source": "header",
                "name": "X-Webhook-Token"
              }
            }
          },
          {
            "match": {
              "type": "value",
              "value": "WEBHOOK_TOKEN_ACTIVE",
              "parameter": {
                "source": "header",
                "name": "X-Webhook-Token"
              }
            }
          },
          {
            "match": {
              "type": "value",
              "value": "WEBHOOK_TOKEN_RESET17",
              "parameter": {
                "source": "header",
                "name": "X-Webhook-Token"
              }
            }
          }
        ]
      },
      "pass-arguments-to-command": [
        {
          "source": "header",
          "name": "X-Webhook-Token"
        }
      ],
      "command-working-directory": "/",
      "execute-command": "/run/current-system/sw/bin/webhook-postgres-reset",
      "response-message": "Database operation completed successfully",
      "include-command-output-in-response": true
    }]
  '';

  # Create a derivation that combines all scripts and webhook config
  postgres13-reset-pkg = pkgs.symlinkJoin {
    name = "postgres13-reset";
    paths = [
      (pkgs.writeTextFile {
        name = "webhook-config";
        text = webhookConfig;
        destination = "/etc/webhook/hooks.json.template";
      })
      postgres13-rollback
      postgres13-activate
      postgres13-create-base
      postgres17-rollback
      webhook-handler
      postgres13-reset
      postgres13-activate-cmd
    ];
  };
in
postgres13-reset-pkg
