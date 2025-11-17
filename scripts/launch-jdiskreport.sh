#!/usr/bin/env bash
set -euo pipefail

# Launch JDiskReport with Java 8 via nix-shell
# This app is from 2014 and requires Java 8 for compatibility

echo "Launching JDiskReport with Java 8..."
echo "Note: This will run in the foreground. Press Ctrl+C to exit."
echo ""

# Use nix-shell to provide Java 8, then launch the JAR
nix-shell -p jdk8 --run "java -jar /Applications/JDiskReport.app/Contents/Java/jdiskreport-1.4.1.jar $*"
