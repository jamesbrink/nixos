{ pkgs }:

pkgs.writeScriptBin "postgis-rollback" ''
  #!${pkgs.bash}/bin/bash

  # Exit on any error
  set -e

  echo "Stopping podman-postgis service..."
  sudo systemctl stop podman-postgis.service

  # Wait for the service to fully stop
  echo "Waiting for service to stop completely..."
  while sudo systemctl is-active --quiet podman-postgis.service; do
      echo -n "."
      sleep 1
  done
  echo "Service stopped"

  # Perform the ZFS rollback
  echo "Rolling back ZFS dataset..."
  sudo zfs rollback -r storage-fast/quantierra@dev

  # Start the service back up
  echo "Starting podman-postgis service..."
  sudo systemctl start podman-postgis.service

  echo "Rollback complete!"
''
