#!/usr/bin/env bash
set -euo pipefail

# Script to upgrade all GitHub Actions runner scale sets to use the custom image
# Usage: ./upgrade-runner-image.sh

NAMESPACE="github-runners"
SECRET_NAME="gha-controller-manager"
CHART="oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"

echo "Upgrading GitHub Actions runners to use custom image: ghcr.io/jamesbrink/github-runner-full:latest"
echo ""

# Get GitHub PAT from existing secret
echo "Retrieving GitHub PAT from k8s secret..."
GITHUB_PAT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.github_token}' | base64 -d)

if [ -z "$GITHUB_PAT" ]; then
    echo "❌ Error: Could not retrieve GitHub PAT from secret"
    exit 1
fi

echo "✅ GitHub PAT retrieved"
echo ""

# Upgrade each tier
TIERS=("xl" "l" "m" "s")

for tier in "${TIERS[@]}"; do
    echo "Upgrading runner scale set: arc-runner-set-$tier"

    helm upgrade "arc-runner-set-$tier" \
        --namespace "$NAMESPACE" \
        --set githubConfigSecret.github_token="$GITHUB_PAT" \
        -f "values-$tier.yaml" \
        "$CHART"

    echo "✅ arc-runner-set-$tier upgraded"
    echo ""
done

echo "🎉 All runner scale sets upgraded successfully!"
echo ""
echo "Checking pod status..."
kubectl get pods -n "$NAMESPACE" -o wide
echo ""
echo "To verify the new image is in use:"
printf "  kubectl get pods -n %s -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.spec.containers[0].image}{\"\\n\"}{end}'\n" "$NAMESPACE"
