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

- **8 total runners** registered with GitHub (2 XL, 0 L, 2 M, 4 S)
- **4 tiers** (XL, L, M, S) with intelligent overflow scheduling across nodes
- **Official GitHub ARC** v0.13.0 (replaced deprecated summerwind/ARC)
- **Node distribution**: hal9000 (3 runners: 2 XL + 1 M overflow), alienware (1 M), n100s (4 S, 1 per node)

## Runner Tiers

### selfhost-xl (XL Tier)

- **Node**: hal9000 (gha-tier: selfhost-l)
- **Resources**: 8-32 CPU (request-limit), 16-64Gi memory, **no limits** (prevents OOM on large jobs)
- **Scale**: min 2, max 2 (always-on for heavy workloads)
- **Current**: 2 runners online
- **Use case**: Large test suites, parallel testing, memory-intensive builds

### selfhost-l (L Tier)

- **Nodes**: hal9000 OR alienware (gha-tier: selfhost-l or selfhost-m)
- **Resources**: 1-4 CPU, 2-8Gi memory
- **Scale**: min 0, max 10 (on-demand scaling)
- **Current**: 0 runners (scales up automatically when needed)
- **Use case**: General CI/CD tasks, medium builds

### selfhost-m (M Tier)

- **Nodes**: alienware (preferred), hal9000 (overflow)
- **Resources**: 1-4 CPU, 2-8Gi memory
- **Scale**: min 2, max 6
- **Current**: 2 runners online
- **Overflow**: Can schedule on hal9000 when alienware is full
- **Use case**: Standard builds, Docker operations

### selfhost-s (S Tier)

- **Nodes**: n100-01/02/03/04 (preferred), alienware/hal9000 (overflow)
- **Resources**: 1-2 CPU, 2-4Gi memory
- **Scale**: min 4, max 8
- **Current**: 4 runners online (1 per n100 node)
- **Topology**: Spread across n100 nodes, can overflow to larger nodes when needed
- **Overflow priority**: n100s → alienware → hal9000
- **Use case**: Linting, type checking, small tests

## Usage in Workflows

Reference runner scale set names directly (no labels):

```yaml
jobs:
  # Large parallel test suite
  test-parallel:
    runs-on: selfhost-xl # XL: 32 CPU, 64GB RAM, always available

  # Standard build
  build:
    runs-on: selfhost-l # L: 4 CPU, 8GB RAM, scales on-demand

  # Docker operations
  docker-build:
    runs-on: selfhost-m # M: 4 CPU, 8GB RAM, always available

  # Lint and type check
  lint:
    runs-on: selfhost-s # S: 2 CPU, 4GB RAM, distributed across n100s
```

**Important**: Use exact scale set names - `selfhost-xl`, `selfhost-l`, `selfhost-m`, `selfhost-s` (NOT `selfhosted-*`)

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

**Runner Image**: All tiers use the custom runner image `ghcr.io/jamesbrink/github-runner-full:latest` which includes:

- Python 3.11, 3.12, 3.13 (with uv, poetry, pytest, black, ruff)
- libpostal (C library + Python bindings + pre-downloaded data)
- Node.js, Go, Rust, Ruby, Java, .NET, Nix
- Docker CLI, kubectl, Helm, Terraform
- AWS CLI, Azure CLI, Google Cloud SDK
- PostgreSQL client, poppler-utils, and more

See `containers/github-runner-full/README.md` for complete tool list.

**Important**: The `github_token` field in these files is set to `REDACTED` to avoid committing secrets to git.

**Recommended**: Use the automated deployment script that injects secrets from agenix:

```bash
# Deploy all runner tiers with automatic secret injection
../../scripts/deploy-k8s.py github-runners

# Deploy a specific tier
../../scripts/deploy-k8s.py github-runners --tier xl
../../scripts/deploy-k8s.py github-runners --tier l
../../scripts/deploy-k8s.py github-runners --tier m
../../scripts/deploy-k8s.py github-runners --tier s

# Dry run (preview without deploying)
../../scripts/deploy-k8s.py --dry-run github-runners --tier xl
```

The script automatically reads the GitHub PAT from `secrets/jamesbrink/github/quantierra-runner-token.age` and injects it at deployment time. Values files always stay with `REDACTED` in git.

**Manual deployment** (if needed):

```bash
# Option 1: Use sed to replace inline
sed 's/REDACTED/YOUR_GITHUB_PAT/' values-xl.yaml | helm install arc-runner-set-xl ...

# Option 2: Set via --set flag
helm install arc-runner-set-xl --set githubConfigSecret.github_token="YOUR_PAT" ...
```

See `../../scripts/README-deploy-k8s.md` for full documentation on the deployment script.

## Upgrading Runner Image

### Quick Update (kubectl patch)

Use the `patch-runner-image.sh` script to update without needing the GitHub PAT:

```bash
./patch-runner-image.sh
```

This patches the runner scale sets directly via kubectl API.

### Full Helm Upgrade

For complete upgrades or configuration changes:

```bash
# Get the GitHub PAT from the secret
export GITHUB_PAT=$(kubectl get secret gha-controller-manager -n github-runners -o jsonpath='{.data.github_token}' | base64 -d)

# Option 1: Use the upgrade script
./upgrade-runner-image.sh

# Option 2: Upgrade tiers individually
helm upgrade arc-runner-set-xl \
  --namespace github-runners \
  --set githubConfigSecret.github_token="$GITHUB_PAT" \
  -f values-xl.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# Repeat for l, m, s tiers...
```

**Note**: The upgrade will:

1. Pull the new image to each node (may take 5-10 minutes for ~13-14GB image)
2. Restart runner pods with the new image
3. Re-register runners with GitHub
4. XL runners on hal9000 may briefly contend for resources during rollout

**Automated Updates**: The `check-upstream-runner` GitHub Actions workflow checks daily for upstream actions-runner image updates and creates PRs automatically

## Monitoring

Check runner status:

```bash
# K8s pods
kubectl get pods -n github-runners -o wide

# Check image in use
kubectl get pods -n github-runners -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# GitHub runners
gh api orgs/quantierra/actions/runners --jq '.runners[] | {name, status, busy}'

# Helm releases
helm list -n arc-systems
helm list -n github-runners
```

## Node Resources

### Node Capacity and Allocation

| Node          | CPU      | RAM  | Current Allocation  | Primary Tiers   | Overflow Tiers |
| ------------- | -------- | ---- | ------------------- | --------------- | -------------- |
| **hal9000**   | 32 cores | 64GB | 2 XL (16-64Gi each) | XL (always-on)  | L, M, S        |
| **alienware** | 12 cores | 31GB | 2 M (2-8Gi each)    | M (2-6 runners) | L, S           |
| **n100-01**   | 4 cores  | 16GB | 1 S (2-4Gi)         | S (1-2 runners) | -              |
| **n100-02**   | 4 cores  | 16GB | 1 S (2-4Gi)         | S (1-2 runners) | -              |
| **n100-03**   | 4 cores  | 16GB | 1 S (2-4Gi)         | S (1-2 runners) | -              |
| **n100-04**   | 4 cores  | 16GB | 1 S (2-4Gi)         | S (1-2 runners) | -              |

**Notes:**

- hal9000 shows 231% memory overcommit on limits, but actual usage is typically <50%
- XL runners have no memory limits to prevent OOM on large parallel test jobs
- All runner tiers use node affinity with overflow capabilities:
  - **L runners**: hal9000 OR alienware
  - **M runners**: alienware (preferred) → hal9000 (overflow)
  - **S runners**: n100s (preferred) → alienware → hal9000 (overflow)

### Node Labels

Labels managed via NixOS k3s module:

- **hal9000**: `gha-tier=selfhost-l` (XL primary, L primary, M overflow, S overflow)
- **alienware**: `gha-tier=selfhost-m` (M primary, L overflow, S overflow)
- **n100-01/02/03/04**: `gha-tier=selfhost-s` (S primary only)

**Overflow Scheduling:**

Runner tiers use Kubernetes node affinity with multiple acceptable label values. When primary nodes are at capacity or unavailable, new runners automatically schedule on overflow nodes:

- **XL**: Only hal9000 (no overflow)
- **L**: hal9000 OR alienware (equal preference)
- **M**: Prefers alienware, overflows to hal9000
- **S**: Prefers n100s, overflows to alienware, then hal9000

## Troubleshooting

### OOM (Out of Memory) Issues

If runners are getting OOMKilled:

1. **Check actual memory usage**:

   ```bash
   kubectl top pods -n github-runners --containers
   ```

2. **Check node pressure**:

   ```bash
   kubectl describe node hal9000 | grep -A 10 "Allocated resources"
   ```

3. **For XL runners**: Memory limits are set to 64Gi (full node capacity). Jobs using >64GB will OOM.

   - Solution: Split parallel jobs or use fewer workers

4. **For other tiers**: Increase limits in values-\*.yaml if consistently hitting OOM

### Runners Not Picking Up Jobs

If workflows show "Waiting for a runner to pick up this job...":

1. **Check runner scale set name**:

   - Workflow must use: `runs-on: selfhost-xl` (NOT `selfhost-xl` with different spelling)
   - Valid names: `selfhost-xl`, `selfhost-l`, `selfhost-m`, `selfhost-s`

2. **Check runner status**:

   ```bash
   gh api orgs/quantierra/actions/runners --jq '.runners[] | select(.name | startswith("selfhost-")) | {name, status, busy}'
   ```

3. **Check for failed pods**:
   ```bash
   kubectl get pods -n github-runners -l app.kubernetes.io/component=runner
   kubectl get ephemeralrunners -n github-runners
   ```

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
