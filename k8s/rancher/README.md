# Rancher Deployment

Rancher management platform for Kubernetes with integrated monitoring stack.

## Overview

- **Rancher Version**: 2.12.3
- **Monitoring Version**: 107.2.1+up69.8.2-rancher.23 (kube-prometheus-stack)
- **URL**: <https://rancher.home.urandom.io>
- **Grafana URL**: <https://grafana.home.urandom.io>

## Architecture

### Node Placement

All Rancher and monitoring components run on **hal9000**:

- Rancher server
- Prometheus
- Grafana
- Alertmanager
- Prometheus Operator

### Monitoring Coverage

Metrics collection across all cluster nodes:

- **Node Exporter**: DaemonSet on all nodes (hal9000, alienware, n100-01/02/03/04, derp)
- **kube-state-metrics**: Cluster-wide metrics
- **CoreDNS, kubelet, API server, etc.**: All Kubernetes components monitored

## Components

### Rancher Credentials

- Management UI for Kubernetes
- Multi-cluster management
- RBAC and user management
- App catalog integration

### Monitoring Components

- **Prometheus**: Metrics collection and storage (30d retention, 50Gi)
- **Grafana**: Dashboards and visualization
- **Alertmanager**: Alert routing and management
- **Node Exporter**: Node-level metrics from all hosts
- **kube-state-metrics**: Kubernetes object metrics

## TLS/Certificates

Uses existing wildcard certificate:

- Secret: `wildcard-home-urandom-io` (from traefik namespace)
- Covers: `*.home.urandom.io`
- Issuer: Let's Encrypt (letsencrypt-production)

## Deployment

### Automated Deployment (Recommended)

Deploy both Rancher and monitoring using the automated script:

```bash
./scripts/deploy-rancher.sh
```

This script will:

1. Deploy Rancher Server 2.12.3
2. Deploy Rancher Monitoring stack with integrated dashboards
3. Configure node affinity for hal9000
4. Set up Grafana ingress at grafana.home.urandom.io

### Manual Deployment

#### Rancher Server

```bash
# Add Helm repos
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo add rancher-charts https://charts.rancher.io
helm repo update

# Create namespace
kubectl create namespace cattle-system

# Copy wildcard cert to cattle-system namespace
kubectl get secret wildcard-home-urandom-io -n traefik -o yaml | \
  sed 's/namespace: traefik/namespace: cattle-system/' | \
  kubectl apply -f -

# Install Rancher
helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --values k8s/rancher/values.yaml \
  --version 2.12.3
```

#### Monitoring Stack Deployment

```bash
# Create monitoring namespace
kubectl create namespace cattle-monitoring-system

# Copy wildcard cert to monitoring namespace
kubectl get secret wildcard-home-urandom-io -n traefik -o yaml | \
  sed 's/namespace: traefik/namespace: cattle-monitoring-system/' | \
  kubectl apply -f -

# Install Rancher Monitoring
helm upgrade --install rancher-monitoring rancher-charts/rancher-monitoring \
  --namespace cattle-monitoring-system \
  --values k8s/rancher/monitoring-values.yaml \
  --wait \
  --timeout 10m

# Sync Grafana proxy config for Rancher UI embedding
kubectl create configmap grafana-nginx-proxy-config \
  -n cattle-monitoring-system \
  --from-file=nginx.conf=k8s/rancher/grafana-nginx.conf \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/rancher-monitoring-grafana -n cattle-monitoring-system

> **Note**: `k8s/rancher/monitoring-values.yaml` pins `global.cattle.clusterId` / `clusterName` to `local` and leaves `grafana.ini.server.domain` blank so Grafana respects whichever host (Rancher proxy or grafana.home.urandom.io) served the UI. Without these values Rancher opens Grafana to a 404 and login never sticks.
```

**Note**: See [INSTALL-MONITORING.md](INSTALL-MONITORING.md) for alternative Rancher UI-based installation method.

## Default Credentials

### Rancher Capacity

- **URL**: <https://rancher.home.urandom.io>
- **Username**: admin
- **Password**: admin (change on first login)

### Grafana Credentials

- **URL**: <https://grafana.home.urandom.io>
- **Username**: admin
- **Password**: admin (change on first login)

## Resource Requirements

### Rancher

- CPU: 1-2 cores
- Memory: 2-4 Gi

### Monitoring Requirements

- CPU: ~2.7 cores limit, ~1.25 cores request
- Memory: ~4Gi limit, ~2.2Gi request
- Storage: 50Gi (Prometheus) + 10Gi (Grafana) + 10Gi (Alertmanager)

## Verification

Check deployment status:

```bash
# Rancher
kubectl get pods -n cattle-system
kubectl get ingress -n cattle-system

# Monitoring
kubectl get pods -n cattle-monitoring-system
kubectl get ingress -n cattle-monitoring-system

# Check if Rancher is ready
kubectl rollout status deployment/rancher -n cattle-system
```

## Uninstallation

```bash
# Remove monitoring
helm uninstall rancher-monitoring -n cattle-monitoring-system
kubectl delete namespace cattle-monitoring-system
kubectl delete namespace cattle-dashboards

# Remove Rancher
helm uninstall rancher -n cattle-system
kubectl delete namespace cattle-system
```

## Notes

- Rancher manages the local k3s cluster automatically upon deployment
- Additional clusters can be imported through the Rancher UI
- Monitoring dashboards are pre-configured for Kubernetes metrics
- Custom dashboards can be added through Grafana UI or ConfigMaps
