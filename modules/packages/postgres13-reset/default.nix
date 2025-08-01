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

    echo "Killing PostgreSQL 13 container..."
    sudo ${pkgs.podman}/bin/podman kill postgres13 || true
    echo "Container killed"

    # Destroy the existing clone and all its snapshots
    echo "Destroying existing dev clone and snapshots..."
    sudo ${pkgs.zfs}/bin/zfs destroy -r storage-fast/quantierra/postgres13

    echo "Creating new clone from storage-fast/quantierra/base@backup_20250727..."
    sudo ${pkgs.zfs}/bin/zfs clone storage-fast/quantierra/base@backup_20250727 storage-fast/quantierra/postgres13
    sudo touch /storage-fast/quantierra/postgres13/standby.signal

    # Start the service back up
    echo "Starting podman-postgres13 service..."
    sudo ${pkgs.systemd}/bin/systemctl start podman-postgres13.service

    echo "Reset complete!"
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
      "response-message": "Database reset completed successfully",
      "include-command-output-in-response": true
    }]
  '';

  # Create a derivation that combines all scripts and webhook config
  postgres13-reset = pkgs.symlinkJoin {
    name = "postgres13-reset";
    paths = [
      (pkgs.writeTextFile {
        name = "webhook-config";
        text = webhookConfig;
        destination = "/etc/webhook/hooks.json.template";
      })
      postgres13-rollback
      postgres17-rollback
      webhook-handler
    ];
  };
in
postgres13-reset
