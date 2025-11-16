# Quantierra GitHub Actions Runners

Goal: deploy auto-scaled org-level self-hosted GitHub Actions runners for the `quantierra` organization on Kubernetes (non-NixOS) so any host with kubeconfig + Helm can launch/operate workers.

## Deployment Approach

1. **Controller**: upstream `actions-runner-controller` (ARC) Helm chart drives all lifecycle operations (runner pods, autoscaling, GitHub sync).
2. **Runner Scale Set**: one `RunnerDeployment` + `HorizontalRunnerAutoscaler` pair keeps at least one warm runner and bursts to 15 for heavy CI.
3. **Secrets**: a high-scope GitHub PAT (including `admin:org`) lives in `secrets/jamesbrink/github/quantierra-runner-token.age` and syncs into the cluster as the `gha-controller-manager` secret.
4. **Namespace**: everything (CRDs, runners, Helm release) runs inside the dedicated `github-runners` namespace managed via `manifests/namespace.yaml`.
5. **Images**: both ARC and the runners pin `ghcr.io/actions/actions-runner:v2.329.0`, matching the latest official runner release (update this when GitHub publishes a new version).

## Directory Layout

```
quantierra-github-runners/
├── charts/
│   ├── values.base.yaml     # shared ARC settings (secret name, image pin, SA)
│   ├── values.prod.yaml     # prod-only toggles (tolerations, metrics, replicas)
│   └── secrets.example.yaml # documents which agenix secret feeds Kubernetes
└── manifests/
    ├── namespace.yaml       # namespace + quotas/limits
    ├── actions.summerwind.dev_*.yaml # ARC CRDs (synced from Helm)
    └── runners.yaml         # RunnerDeployment + HorizontalRunnerAutoscaler
```

## Implementation Plan

1. **Secret prep**

   - Populate `secrets/jamesbrink/github/quantierra-runner-token.age` with a PAT that has `admin:org`, `repo`, and `workflow`.
   - Run `scripts/deploy-quantierra-github-runners.sh --sync-secret` (or the full deploy script) to push it to Kubernetes as `gha-controller-manager`.

2. **Bootstrap namespace + CRDs**

   - `kubectl apply -f k8s/quantierra-github-runners/manifests/namespace.yaml`
   - `kubectl apply -f k8s/quantierra-github-runners/manifests/actions.summerwind.dev_*.yaml`

3. **Install ARC**

   - `scripts/deploy-quantierra-github-runners.sh --helm-only` (or run Helm manually with the two values files and chart version `0.23.7`).

4. **RunnerDeployment**

   - `kubectl apply -f k8s/quantierra-github-runners/manifests/runners.yaml` to create the org-level runner set + autoscaler.

5. **Monitoring & upgrades**
   - `kubectl get runners -n github-runners` confirms registration.
   - Update `charts/values.*` + `manifests/runners.yaml` when GitHub publishes a new runner image or new scale policy; rerun the deploy script.

## Operational Checklist

- [ ] kubecontext for `hal9000` cluster available (see `SECRETS.md`).
- [ ] `secrets/jamesbrink/github/quantierra-runner-token.age` rotated when PAT scopes change; re-run deploy script afterward.
- [ ] `helm list -n github-runners` shows `quantierra-gha-controller` at chart `0.23.7`.
- [ ] `kubectl get runners -n github-runners` reports Ready pods labeled `org=quantierra`.
- [ ] `kubectl logs deployment/quantierra-gha-controller actions-runner-controller -n github-runners` clean (no auth errors).
