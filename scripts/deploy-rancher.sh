#!/usr/bin/env bash
set -euo pipefail

# Deploy Rancher and Monitoring to k3s cluster

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RANCHER_VALUES="$PROJECT_ROOT/k8s/rancher/values.yaml"
MONITORING_VALUES="$PROJECT_ROOT/k8s/rancher/monitoring-values.yaml"

RANCHER_VERSION="2.12.3"

CATTLE_NAMESPACE="cattle-system"
MONITORING_NAMESPACE="cattle-monitoring-system"

WILDCARD_CERT_SECRET="wildcard-home-urandom-io"
WILDCARD_CERT_NAMESPACE="traefik"

echo "========================================="
echo "Rancher Deployment"
echo "========================================="
echo "Rancher Version: $RANCHER_VERSION"
echo "========================================="
echo ""

# Check if running on hal9000 or has kubectl access
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Make sure you have kubectl configured or run this on hal9000"
    exit 1
fi

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable 2>/dev/null || true
helm repo add rancher-charts https://charts.rancher.io 2>/dev/null || true
helm repo update

echo ""
echo "========================================="
echo "Deploying Rancher"
echo "========================================="

# Create cattle-system namespace
echo "Creating namespace: $CATTLE_NAMESPACE"
kubectl create namespace $CATTLE_NAMESPACE 2>/dev/null || echo "Namespace $CATTLE_NAMESPACE already exists"

# Copy wildcard certificate to cattle-system namespace
echo "Copying wildcard certificate to $CATTLE_NAMESPACE..."
if kubectl get secret $WILDCARD_CERT_SECRET -n $WILDCARD_CERT_NAMESPACE &>/dev/null; then
    kubectl get secret $WILDCARD_CERT_SECRET -n $WILDCARD_CERT_NAMESPACE -o yaml | \
        sed "s/namespace: $WILDCARD_CERT_NAMESPACE/namespace: $CATTLE_NAMESPACE/" | \
        kubectl apply -f - || echo "Warning: Failed to copy certificate"
else
    echo "Error: Wildcard certificate $WILDCARD_CERT_SECRET not found in namespace $WILDCARD_CERT_NAMESPACE"
    exit 1
fi

# Install/upgrade Rancher
echo ""
echo "Installing Rancher $RANCHER_VERSION..."
helm upgrade --install rancher rancher-stable/rancher \
    --namespace $CATTLE_NAMESPACE \
    --values "$RANCHER_VALUES" \
    --version "$RANCHER_VERSION" \
    --wait \
    --timeout 10m

echo ""
echo "Waiting for Rancher to be ready..."
kubectl rollout status deployment/rancher -n $CATTLE_NAMESPACE --timeout=10m

echo ""
echo "========================================="
echo "Deploying Rancher Monitoring"
echo "========================================="

# Create monitoring namespace
echo "Creating namespace: $MONITORING_NAMESPACE"
kubectl create namespace $MONITORING_NAMESPACE 2>/dev/null || echo "Namespace $MONITORING_NAMESPACE already exists"

# Copy wildcard certificate to monitoring namespace
echo "Copying wildcard certificate to $MONITORING_NAMESPACE..."
if kubectl get secret $WILDCARD_CERT_SECRET -n $WILDCARD_CERT_NAMESPACE &>/dev/null; then
    kubectl get secret $WILDCARD_CERT_SECRET -n $WILDCARD_CERT_NAMESPACE -o yaml | \
        sed "s/namespace: $WILDCARD_CERT_NAMESPACE/namespace: $MONITORING_NAMESPACE/" | \
        kubectl apply -f - || echo "Warning: Failed to copy certificate"
else
    echo "Warning: Wildcard certificate not found, monitoring ingress may not work"
fi

# Install/upgrade Rancher Monitoring
echo ""
echo "Installing Rancher Monitoring..."
helm upgrade --install rancher-monitoring rancher-charts/rancher-monitoring \
    --namespace $MONITORING_NAMESPACE \
    --values "$MONITORING_VALUES" \
    --wait \
    --timeout 10m

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Rancher UI:    https://rancher.home.urandom.io"
echo "Grafana UI:    https://grafana.home.urandom.io"
echo ""
echo "Default credentials (change on first login):"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Grafana admin password:"
echo "  kubectl get secret -n cattle-monitoring-system rancher-monitoring-grafana \\"
echo "    -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n $CATTLE_NAMESPACE"
echo "  kubectl get pods -n $MONITORING_NAMESPACE"
echo "  kubectl get ingress -n $CATTLE_NAMESPACE"
echo "  kubectl get ingress -n $MONITORING_NAMESPACE"
echo ""
echo "Dashboard count:"
echo "  kubectl get configmap -n cattle-dashboards --no-headers | wc -l"
echo ""
