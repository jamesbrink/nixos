#!/usr/bin/env bash
set -euo pipefail

# Build script for GitHub Actions runner full image

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/jamesbrink/github-runner-full}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
PLATFORM="${PLATFORM:-linux/amd64}"

echo "Building image: ${FULL_IMAGE}"
echo "Platform: ${PLATFORM}"
echo ""

# Detect if running on ARM64 Mac
if [[ "$(uname -m)" == "arm64" && "$(uname -s)" == "Darwin" ]]; then
    echo "⚠️  Detected ARM64 Mac - building for linux/amd64"
    echo "Note: Verification step is disabled in Dockerfile for cross-platform builds"
    echo ""
fi

# Build the image with explicit platform
docker buildx build \
  --platform "${PLATFORM}" \
  --progress=plain \
  --load \
  -t "${FULL_IMAGE}" \
  .

echo ""
echo "✅ Image built successfully: ${FULL_IMAGE}"
echo ""
echo "Note: The image was built for ${PLATFORM}"
echo "      GitHub Actions runners use linux/amd64"
echo ""
echo "To push the image:"
echo "  docker push ${FULL_IMAGE}"
echo ""
echo "To use in runner scale sets, update your values files:"
echo "  image: ${FULL_IMAGE}"
