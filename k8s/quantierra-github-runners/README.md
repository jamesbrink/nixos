# Quantierra GitHub Actions Runners

GitHub Actions self-hosted runner scale sets for the `quantierra` organization using the official GitHub Actions Runner Controller (ARC).

## Architecture

**Controller**: GitHub's official Actions Runner Controller v0.13.0

- Deployed in `arc-systems` namespace
- Manages all runner scale sets

**Runner Scale Sets**: Four tiers based on resource requirements

- Deployed in `github-runners` namespace
- Auto-scale based on workflow demand

## Deployment Status

✅ **All runners online and healthy**

- **11 total runners** registered with GitHub
- **4 tiers** (XL, L, M, S) distributed across nodes
- **Official GitHub ARC** v0.13.0 (replaced deprecated summerwind/ARC)

## Runner Tiers

### selfhost-xl (XL Tier)

- **Node**: hal9000 (gha-tier: selfhost-l)
- **Resources**: 8-16 CPU, 16-32Gi memory
- **Scale**: min 1, max 2
- **Current**: 1 runner online

### selfhost-l (L Tier)

- **Node**: hal9000 (gha-tier: selfhost-l)
- **Resources**: 1-4 CPU, 2-8Gi memory
- **Scale**: min 4, max 10
- **Current**: 4 runners online

### selfhost-m (M Tier)

- **Node**: alienware (gha-tier: selfhost-m)
- **Resources**: 1-4 CPU, 2-8Gi memory
- **Scale**: min 2, max 6
- **Current**: 2 runners online

### selfhost-s (S Tier)

- **Nodes**: n100-01/02/03/04 (gha-tier: selfhost-s)
- **Resources**: 1-2 CPU, 2-4Gi memory
- **Scale**: min 4, max 8
- **Current**: 4 runners online (1 per n100 node)

## Usage in Workflows

Reference runner tiers in your workflows:

```yaml
jobs:
  build:
    runs-on: selfhost-xl # Use XL runner

  test:
    runs-on: selfhost-l # Use L runner

  deploy:
    runs-on: selfhost-m # Use M runner

  lint:
    runs-on: selfhost-s # Use S runner
```

## Installation

The deployment consists of:

1. **Controller** (one-time):

```bash
helm install arc \
  --namespace arc-systems \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

2. **Runner Scale Sets** (per tier):

```bash
# XL Tier
helm install arc-runner-set-xl \
  --namespace github-runners \
  -f values-xl.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# L Tier
helm install arc-runner-set-l \
  --namespace github-runners \
  -f values-l.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# M Tier
helm install arc-runner-set-m \
  --namespace github-runners \
  -f values-m.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# S Tier
helm install arc-runner-set-s \
  --namespace github-runners \
  -f values-s.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Configuration

Values files are located in this directory:

- `values-xl.yaml` - XL tier configuration
- `values-l.yaml` - L tier configuration
- `values-m.yaml` - M tier configuration
- `values-s.yaml` - S tier configuration

**Important**: The `github_token` field in these files is set to `REDACTED`. Replace with actual GitHub PAT when deploying:

```bash
# Option 1: Use sed to replace inline
sed 's/REDACTED/YOUR_GITHUB_PAT/' values-xl.yaml | helm install arc-runner-set-xl ...

# Option 2: Set via --set flag
helm install arc-runner-set-xl --set githubConfigSecret.github_token="YOUR_PAT" ...
```

The PAT is also available in the existing K8s secret `gha-controller-manager` in the `github-runners` namespace.

## Monitoring

Check runner status:

```bash
# K8s pods
kubectl get pods -n github-runners -o wide

# GitHub runners
gh api orgs/quantierra/actions/runners --jq '.runners[] | {name, status, busy}'

# Helm releases
helm list -n arc-systems
helm list -n github-runners
```

## Node Labels

Node labels are managed via NixOS k3s module:

- **hal9000**: `gha-tier=selfhost-l` (runs XL and L tiers)
- **alienware**: `gha-tier=selfhost-m` (runs M tier)
- **n100-01/02/03/04**: `gha-tier=selfhost-s` (runs S tier)

## Secrets

GitHub PAT stored in:

- K8s secret: `gha-controller-manager` in `github-runners` namespace
- Source: `secrets/jamesbrink/github/quantierra-runner-token.age`

## Migration Notes

This deployment replaces the deprecated summerwind/actions-runner-controller with GitHub's official ARC:

- ✅ Old controller uninstalled
- ✅ Old CRDs removed
- ✅ Old manifests archived in `.old-summerwind/`
- ✅ New architecture using runner scale sets
- ✅ All runners registered and healthy

## References

- [Official GitHub ARC Documentation](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller)
- [GitHub ARC Repository](https://github.com/actions/actions-runner-controller)
- Runner tier details: `RUNNER_TIERS.md`
