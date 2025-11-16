#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'EOF'
Usage: ./scripts/deploy-quantierra-github-runners.sh [options]

Options:
  --sync-secret-only   Only sync the GitHub token secret (still ensures namespace exists).
  --helm-only          Apply namespace & CRDs and run the Helm upgrade (skip secret + runner manifest).
  --skip-runner        Skip RunnerDeployment/HorizontalRunnerAutoscaler apply.
  --skip-secret        Skip secret sync.
  -h, --help           Show this help message.

Without flags the script performs the full deployment flow:
  1. Apply namespace + quotas.
  2. Apply ARC CRDs.
  3. Sync the GitHub PAT secret (gha-controller-manager).
  4. Helm upgrade/install actions-runner-controller.
  5. Apply RunnerDeployment + autoscaler resources.
EOF
}

SYNC_SECRET=true
RUN_HELM=true
APPLY_RUNNER_MANIFEST=true
SYNC_SECRET_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync-secret-only)
      SYNC_SECRET_ONLY=true
      RUN_HELM=false
      APPLY_RUNNER_MANIFEST=false
      shift
      ;;
    --helm-only)
      SYNC_SECRET=false
      APPLY_RUNNER_MANIFEST=false
      shift
      ;;
    --skip-runner)
      APPLY_RUNNER_MANIFEST=false
      shift
      ;;
    --skip-secret)
      SYNC_SECRET=false
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="$ROOT_DIR/k8s/quantierra-github-runners"
NAMESPACE="github-runners"
SECRET_FILE="jamesbrink/github/quantierra-runner-token.age"
SECRET_NAME="gha-controller-manager"
HELM_RELEASE="quantierra-gha-controller"
CHART="actions-runner-controller/actions-runner-controller"
CHART_VERSION="0.23.7"
VALUES_BASE="$K8S_DIR/charts/values.base.yaml"
VALUES_PROD="$K8S_DIR/charts/values.prod.yaml"

apply_namespace() {
  echo "Applying namespace + quotas..."
  kubectl apply -f "$K8S_DIR/manifests/namespace.yaml"
}

apply_crds() {
  echo "Applying ARC CRDs..."
  shopt -s nullglob
  local crds=("$K8S_DIR"/manifests/actions.summerwind.dev_*.yaml)
  if [[ ${#crds[@]} -eq 0 ]]; then
    echo "Error: No CRD manifests found in $K8S_DIR/manifests" >&2
    exit 1
  fi
  for crd in "${crds[@]}"; do
    kubectl apply --server-side -f "$crd"
  done
  shopt -u nullglob
}

find_identity() {
  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "$HOME/.ssh/id_ed25519"
  elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
    echo "$HOME/.ssh/id_rsa"
  else
    echo "Error: No SSH identity found to decrypt age secrets." >&2
    exit 1
  fi
}

sync_secret() {
  local identity
  identity="$(find_identity)"
  echo "Syncing GitHub PAT secret to namespace ${NAMESPACE}..."
  local secret_data
  secret_data="$(cd "$ROOT_DIR/secrets" && RULES=./secrets.nix agenix -d "$SECRET_FILE" -i "$identity")"
  local token
  token="$(grep -E '^GITHUB_TOKEN=' <<<"$secret_data" | cut -d'=' -f2- | tr -d '\r\n')"
  if [[ -z "$token" ]]; then
    echo "Error: Failed to parse GITHUB_TOKEN from $SECRET_FILE" >&2
    exit 1
  fi

  kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
    --from-literal=github_token="$token" \
    --dry-run=client -o yaml | kubectl apply -f -
}

install_arc() {
  echo "Installing/upgrading actions-runner-controller..."
  helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1
  helm upgrade --install "$HELM_RELEASE" "$CHART" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --version "$CHART_VERSION" \
    -f "$VALUES_BASE" \
    -f "$VALUES_PROD"
}

apply_runners() {
  echo "Applying RunnerDeployment + autoscaler..."
  kubectl apply -f "$K8S_DIR/manifests/runners.yaml"
}

apply_namespace

if [[ "$SYNC_SECRET_ONLY" == true ]]; then
  SYNC_SECRET && sync_secret
  exit 0
fi

apply_crds

if [[ "$SYNC_SECRET" == true ]]; then
  sync_secret
fi

if [[ "$RUN_HELM" == true ]]; then
  install_arc
fi

if [[ "$APPLY_RUNNER_MANIFEST" == true ]]; then
  apply_runners
fi

echo "Quantierra GitHub runners deployment complete."
