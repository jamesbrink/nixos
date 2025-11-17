#!/usr/bin/env bash
set -euo pipefail

# Script to set the GitHub Container Registry package to public
# This is useful if the workflow fails to set it automatically

PACKAGE_NAME="github-runner-full"

echo "Setting package ${PACKAGE_NAME} to public visibility..."

gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  /user/packages/container/${PACKAGE_NAME} \
  -f visibility='public'

echo "✅ Package ${PACKAGE_NAME} is now public"
echo ""
echo "View at: https://github.com/users/jamesbrink/packages/container/package/${PACKAGE_NAME}"
