# Install Rancher Monitoring via Rancher UI (Alternative Method)

**Note**: The recommended deployment method is via Helm using `./scripts/deploy-rancher.sh`. This guide provides an alternative UI-based installation method.

This guide shows how to install the monitoring stack through Rancher UI. While both Helm and UI methods work, the automated Helm deployment in `deploy-rancher.sh` is faster and more reproducible.

## Prerequisites

- Rancher Server installed and accessible at https://rancher.home.urandom.io
- Logged in as admin user
- Local k3s cluster imported/registered in Rancher

## Installation Steps

### 1. Access Rancher UI

1. Navigate to https://rancher.home.urandom.io
2. Login with credentials:
   - Username: `admin`
   - Password: `admin` (or changed password)

### 2. Navigate to Cluster Tools

1. Click on the local cluster (should be auto-imported)
2. Click **"Cluster Tools"** in the left navigation menu
3. Or go to: **Cluster > Cluster Tools**

### 3. Install Monitoring

1. Find **"Monitoring"** in the available apps
2. Click **"Install"** or **"Enable"**
3. Configure the following settings:

#### Resource Limits

Set these resource limits to match our configuration:

**Prometheus:**

- CPU Request: 750m
- CPU Limit: 1000m
- Memory Request: 1750Mi
- Memory Limit: 2500Mi
- Storage: 50Gi
- Retention: 30d

**Grafana:**

- CPU Request: 100m
- CPU Limit: 200m
- Memory Request: 128Mi
- Memory Limit: 200Mi
- Storage: 10Gi

**Alertmanager:**

- CPU Request: 100m
- CPU Limit: 1000m
- Memory Request: 128Mi
- Memory Limit: 500Mi
- Storage: 10Gi

**Prometheus Operator:**

- CPU Request: 100m
- CPU Limit: 200m
- Memory Request: 128Mi
- Memory Limit: 500Mi

#### Node Placement (IMPORTANT)

Configure node selectors to run monitoring components on hal9000:

**For each component** (Prometheus, Grafana, Alertmanager, Operator):

1. Expand "Node Selector" or "Affinity" section
2. Add node selector:
   - Key: `kubernetes.io/hostname`
   - Value: `hal9000`

Or use affinity rules (preferred):

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - hal9000
```

#### Additional Settings

- **Enable Grafana**: Yes (enabled by default)
- **Prometheus Storage Class**: local-path
- **Enable Persistent Storage**: Yes
- **Enable Node Exporter**: Yes (enabled by default - runs as DaemonSet on all nodes)
- **Enable kube-state-metrics**: Yes (enabled by default)
- **Create Default Dashboards**: Yes (enabled by default)

### 4. Advanced Configuration (Optional)

If you need to set advanced configuration, you can edit the YAML values:

1. Click **"Edit as YAML"** or similar option
2. Paste custom values from `k8s/rancher/monitoring-values.yaml`
3. Adjust as needed for Rancher's chart structure

**Note**: Rancher's monitoring chart may have slightly different value paths than the standalone chart.

### 5. Install and Wait

1. Click **"Install"** at the bottom
2. Wait for deployment to complete (usually 5-10 minutes)
3. Monitor progress in the UI

### 6. Verify Installation

After installation completes:

**Check Pods:**

```bash
kubectl get pods -n cattle-monitoring-system
```

**Check Ingress:**

```bash
kubectl get ingress -n cattle-monitoring-system
```

**Access Grafana:**

- Via Rancher: Navigate to **Monitoring** in the cluster menu
- Direct access: https://grafana.home.urandom.io (if ingress was created)

## Expected Components

After successful installation, you should have:

### Namespaces

- `cattle-monitoring-system` - Main monitoring components
- `cattle-dashboards` - Grafana dashboard ConfigMaps

### Pods (Running on Nodes)

- **hal9000**: Prometheus, Grafana, Alertmanager, Operator, kube-state-metrics, prometheus-adapter
- **All nodes** (DaemonSet): node-exporter

### Services

- Prometheus: ClusterIP on port 9090
- Grafana: ClusterIP on port 80
- Alertmanager: ClusterIP on port 9093

### Dashboards

Rancher should create 30+ default dashboards including:

- Cluster metrics
- Node metrics
- Workload metrics
- Namespace metrics
- Pod metrics
- API server, etcd, controller-manager, scheduler
- CoreDNS, kubelet
- And more...

## Accessing Monitoring

### Via Rancher UI (Recommended)

1. Navigate to your cluster in Rancher
2. Click **"Monitoring"** in the left menu
3. This opens an integrated Grafana view within Rancher
4. All dashboards should be pre-loaded and accessible

### Direct Grafana Access

If you configured an ingress:

- URL: https://grafana.home.urandom.io
- Username: `admin`
- Password: Check the secret:
  ```bash
  kubectl get secret -n cattle-monitoring-system rancher-monitoring-grafana \
    -o jsonpath='{.data.admin-password}' | base64 -d
  ```

## Troubleshooting

### Dashboards Not Loading

If dashboards don't appear:

1. Check that `cattle-dashboards` namespace exists
2. Verify ConfigMaps in cattle-dashboards:
   ```bash
   kubectl get configmap -n cattle-dashboards
   ```
3. Restart Grafana pod to reload dashboards:
   ```bash
   kubectl rollout restart deployment -n cattle-monitoring-system rancher-monitoring-grafana
   ```

### Pods Not Scheduling on hal9000

If monitoring pods end up on other nodes:

1. Check node labels:
   ```bash
   kubectl get nodes --show-labels | grep hostname
   ```
2. Verify node selector in deployment:
   ```bash
   kubectl get deployment -n cattle-monitoring-system rancher-monitoring-grafana -o yaml | grep -A 5 nodeSelector
   ```
3. Edit via Rancher UI or kubectl to add node affinity

### Rancher Integration Not Working

If monitoring doesn't show in Rancher UI:

1. Verify the monitoring app is installed via Rancher (not Helm directly)
2. Check cluster is properly registered in Rancher
3. Try removing and reinstalling from Rancher UI

## Uninstall

To uninstall monitoring:

**Via Rancher UI:**

1. Go to **Cluster Tools**
2. Find **Monitoring**
3. Click **"Uninstall"** or **"Disable"**

**Via CLI:**

```bash
# Delete via Helm (if installed manually)
helm uninstall rancher-monitoring -n cattle-monitoring-system
helm uninstall rancher-monitoring-crd -n cattle-monitoring-system

# Clean up namespaces
kubectl delete namespace cattle-monitoring-system
kubectl delete namespace cattle-dashboards
```

## Notes

- The monitoring stack deployed via Rancher UI has better integration than manual Helm installation
- Rancher handles dashboard provisioning automatically
- The integrated monitoring view in Rancher UI provides a better UX
- Manual Helm installation may have permission issues with dashboard loading

## Reference

- Rancher Monitoring Documentation: https://ranchermanager.docs.rancher.com/integrations-in-rancher/monitoring-and-alerting
- Prometheus Operator: https://github.com/prometheus-operator/prometheus-operator
- Grafana: https://grafana.com/docs/
