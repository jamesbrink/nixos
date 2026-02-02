# urandomio GitHub Actions Runners

GitHub Actions self-hosted runner scale sets for the `urandomio` organization using the official GitHub Actions Runner Controller (ARC).

## Architecture

Shares the existing ARC controller (`arc-systems` namespace) with the quantierra runners. Runner pods deploy to the `github-runners` namespace alongside quantierra runners.

## Runner Tiers

### urandomio-s (S Tier)

- **Nodes**: n100-01/02/03/04 (preferred), alienware/hal9000 (overflow)
- **Resources**: 1-2 CPU, 2-4Gi memory
- **Scale**: min 2, max 4
- **Use case**: Astro builds, linting, small CI jobs

### urandomio-m (M Tier)

- **Nodes**: alienware (preferred), hal9000 (overflow)
- **Resources**: 1-4 CPU, 2-8Gi memory
- **Scale**: min 1, max 2
- **Use case**: Docker builds, heavier CI jobs

## Usage in Workflows

```yaml
jobs:
  build:
    runs-on: urandomio-s  # Small tier for Astro/Node builds

  docker:
    runs-on: urandomio-m  # Medium tier for Docker operations
```

## Installation

Requires a GitHub PAT with `admin:org` scope for the urandomio organization.

### Create GitHub PAT

1. Go to https://github.com/settings/tokens
2. Generate new token (classic) with scopes:
   - `repo` (full)
   - `admin:org` → `manage_runners:org`
3. Store in agenix: `secrets/jamesbrink/github/urandomio-runner-token.age`

### Deploy Runner Scale Sets

```bash
# Using the deployment script (recommended)
../../scripts/deploy-k8s.py urandomio-runners

# Or manually:
# S Tier
helm install arc-runner-set-urandomio-s \
  --namespace github-runners \
  --set githubConfigSecret.github_token="YOUR_PAT" \
  -f values-s.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# M Tier
helm install arc-runner-set-urandomio-m \
  --namespace github-runners \
  --set githubConfigSecret.github_token="YOUR_PAT" \
  -f values-m.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Monitoring

```bash
# Check pods
kubectl get pods -n github-runners -l app.kubernetes.io/instance=arc-runner-set-urandomio-s
kubectl get pods -n github-runners -l app.kubernetes.io/instance=arc-runner-set-urandomio-m

# Check GitHub runner status
gh api orgs/urandomio/actions/runners --jq '.runners[] | {name, status, busy}'
```

## Capacity Notes

These runners share cluster resources with quantierra runners:

- **n100 nodes**: Total 4 S-tier slots shared between quantierra-s (min 4) and urandomio-s (min 2)
- **alienware**: M-tier slots shared between quantierra-m and urandomio-m

During peak usage, topology spread constraints and overflow scheduling ensure fair distribution.

## Secrets

- **PAT location**: `secrets/jamesbrink/github/urandomio-runner-token.age`
- **K8s secret**: Created automatically by Helm during installation
