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

    echo "Stopping podman-postgis service..."
    ${pkgs.systemd}/bin/systemctl stop podman-postgis.service

    # Wait for the service to fully stop
    echo "Waiting for service to stop completely..."
    while ${pkgs.systemd}/bin/systemctl is-active --quiet podman-postgis.service; do
        echo -n "."
        sleep 1
    done
    echo "Service stopped"

    # Destroy the existing clone
    echo "Destroying existing dev clone..."
    ${pkgs.zfs}/bin/zfs destroy storage-fast/quantierra-dev

    # Create a new clone from the dev snapshot
    echo "Creating new clone from dev snapshot..."
    ${pkgs.zfs}/bin/zfs clone storage-fast/quantierra@dev storage-fast/quantierra-dev

    # Start the service back up
    echo "Starting podman-postgis service..."
    ${pkgs.systemd}/bin/systemctl start podman-postgis.service

    echo "Reset complete!"
  '';

  # Create the rollback script for PostgreSQL 17
  postgis17-rollback = pkgs.writeScriptBin "postgis17-rollback" ''
    #!${pkgs.bash}/bin/bash

    # Exit on any error
    set -e

    echo "Stopping podman-postgis17 service..."
    ${pkgs.systemd}/bin/systemctl stop podman-postgis17.service

    # Wait for the service to fully stop
    echo "Waiting for service to stop completely..."
    while ${pkgs.systemd}/bin/systemctl is-active --quiet podman-postgis17.service; do
        echo -n "."
        sleep 1
    done
    echo "Service stopped"

    # Roll back to the upgrade-complete snapshot
    echo "Rolling back to pg17-upgrade-complete snapshot..."
    ${pkgs.zfs}/bin/zfs rollback storage-fast/quantierra-dev-17@pg17-upgrade-complete

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
