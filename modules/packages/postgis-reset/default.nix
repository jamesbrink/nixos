# A package for managing PostGIS database resets using ZFS snapshots
{
  pkgs,
  lib ? pkgs.lib,
}:

let
  # Create the rollback script for PostgreSQL 13
  postgis-rollback = pkgs.writeScriptBin "postgis-rollback" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "Killing PostgreSQL 13 container..."
    ${pkgs.podman}/bin/podman kill postgis13 || true
    echo "Container killed"

    # Destroy the existing clone
    echo "Destroying existing dev clone..."
    ${pkgs.zfs}/bin/zfs destroy storage-fast/quantierra/postgres13

    echo "Creating new clone from storage-fast/quantierra/base@backup_20250227..."
    ${pkgs.zfs}/bin/zfs clone storage-fast/quantierra/base@backup_20250227 storage-fast/quantierra/postgres13
    touch /storage-fast/quantierra/postgres13/standby.signal

    # Start the service back up
    echo "Starting podman-postgis13 service..."
    ${pkgs.systemd}/bin/systemctl start podman-postgis13.service

    echo "Reset complete!"
  '';

  # Create the rollback script for PostgreSQL 17
  postgis17-rollback = pkgs.writeScriptBin "postgis17-rollback" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "Killing PostgreSQL 17 container..."
    ${pkgs.podman}/bin/podman kill postgis17 || true
    echo "Container killed"

    # Roll back to the upgrade-complete snapshot
    echo "Rolling back to pg17-upgrade-complete snapshot..."
    ${pkgs.zfs}/bin/zfs rollback storage-fast/quantierra/postgres13-17@pg17-upgrade-complete

    # Start the service back up
    echo "Starting podman-postgis17 service..."
    ${pkgs.systemd}/bin/systemctl start podman-postgis17.service

    echo "Reset complete!"
  '';

  # Create the webhook handler script
  webhook-handler = pkgs.writeScriptBin "webhook-postgis-reset" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    # Get the token from the first argument
    TOKEN="$1"

    case "$TOKEN" in
      "reset")
        echo "PostgreSQL 13 rollback initiated"
        ${postgis-rollback}/bin/postgis-rollback
        echo "PostgreSQL 13 rollback completed"
        ;;
      "reset17")
        echo "PostgreSQL 17 rollback initiated"
        ${postgis17-rollback}/bin/postgis17-rollback
        echo "PostgreSQL 17 rollback completed"
        ;;
      *)
        echo "Invalid token: $TOKEN"
        exit 1
        ;;
    esac
  '';

  # Create a derivation that combines all scripts and webhook config
  postgis-reset = pkgs.symlinkJoin {
    name = "postgis-reset";
    paths = [
      (pkgs.writeTextFile {
        name = "webhook-config";
        text = builtins.readFile ./hooks.json;
        destination = "/etc/webhook/hooks.json";
      })
      postgis-rollback
      postgis17-rollback
      webhook-handler
    ];
  };
in
postgis-reset
