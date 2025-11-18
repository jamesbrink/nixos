# deploy-k8s.py - Kubernetes Deployment with Secret Injection

Unified Python script for deploying Kubernetes manifests and Helm charts with automatic secret injection from agenix.

## Features

- **Automatic secret injection** - Secrets are read from agenix and injected at deployment time
- **No committed secrets** - Values files can use `REDACTED` placeholders
- **Reusable** - Works for GitHub runners and any other Helm deployments
- **Dry-run support** - Preview what would be deployed
- **Type-safe** - Python with type hints for maintainability

## Prerequisites

- Python 3.6+
- PyYAML: `pip install pyyaml`
- Must be in nix dev shell (for `secrets-print` command)
- kubectl configured
- helm installed

## Usage

### Deploy GitHub Actions Runners

Deploy all runner tiers:

```bash
./scripts/deploy-k8s.py github-runners
```

Deploy a specific tier:

```bash
./scripts/deploy-k8s.py github-runners --tier xl
./scripts/deploy-k8s.py github-runners --tier l
./scripts/deploy-k8s.py github-runners --tier m
./scripts/deploy-k8s.py github-runners --tier s
```

Dry run (preview without deploying):

```bash
./scripts/deploy-k8s.py github-runners --dry-run
```

### Deploy Rancher + Monitoring

Bootstrap or refresh the Rancher control plane plus the monitoring stack (Prometheus/Grafana/Alertmanager):

```bash
./scripts/deploy-k8s.py rancher
```

Use `--dry-run` before rolling out to preview the steps without touching the cluster:

```bash
./scripts/deploy-k8s.py --dry-run rancher
```

This command:

- Ensures the `cattle-system` and `cattle-monitoring-system` namespaces exist
- Copies the wildcard `wildcard-home-urandom-io` certificate from the `traefik` namespace
- Deploys/updates Rancher via `k8s/rancher/values.yaml`
- Deploys/updates the monitoring stack via `k8s/rancher/monitoring-values.yaml`
- Re-syncs the Grafana nginx proxy config and restarts Grafana (handled automatically post-deploy)

### Deploy Generic Helm Chart

Deploy without secret injection:

```bash
./scripts/deploy-k8s.py helm my-release repo/chart \
  --namespace my-namespace \
  --values values.yaml \
  --version 1.2.3
```

Deploy with secret injection:

```bash
./scripts/deploy-k8s.py helm my-release repo/chart \
  --namespace my-namespace \
  --values values.yaml \
  --inject-secret "jamesbrink/github/token:github.token" \
  --inject-secret "jamesbrink/aws/key:aws.secretKey"
```

The `--inject-secret` format is `SECRET_PATH:YAML_PATH` where:

- `SECRET_PATH` is the agenix secret path (without `.age` extension)
- `YAML_PATH` is the dot-notation path in the values YAML (e.g., `a.b.c` sets `values['a']['b']['c']`)

## How It Works

1. **Secret Retrieval**: Uses `secrets-print` command to decrypt agenix secrets
2. **YAML Loading**: Loads base values from YAML files
3. **Secret Injection**: Injects secrets into values dictionary at specified paths
4. **Temporary Files**: Writes modified values to temporary file
5. **Helm Deploy**: Deploys chart with injected secrets
6. **Cleanup**: Removes temporary files

**Important**: Original values files are never modified. Secrets are only in memory and temporary files.

## GitHub Runner Deployment

The GitHub runners deployment is pre-configured:

- **Secret**: `jamesbrink/github/quantierra-runner-token`
- **Injection Path**: `githubConfigSecret.github_token`
- **Chart**: `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set`
- **Version**: 0.13.0
- **Namespace**: github-runners

Tiers:

- **XL**: `arc-runner-set-xl` (values-xl.yaml)
- **L**: `arc-runner-set-l` (values-l.yaml)
- **M**: `arc-runner-set-m` (values-m.yaml)
- **S**: `arc-runner-set-s` (values-s.yaml)

## Adding New Deployments

To add support for a new deployment type:

1. **Create a specialized deployer class** (like `GitHubRunnersDeployer`)
2. **Add a subcommand** to the argument parser
3. **Define secret mappings** for your deployment

Example:

```python
class MyServiceDeployer:
    def __init__(self, project_root: Path, helm_deployer: HelmDeployer):
        self.project_root = project_root
        self.helm_deployer = helm_deployer

    def deploy(self) -> bool:
        values = yaml.safe_load(open("values.yaml"))

        values_with_secrets = self.helm_deployer.inject_secrets(
            values,
            {
                "my/secret/path": "api.token",
                "my/other/secret": "database.password"
            }
        )

        return self.helm_deployer.deploy_chart(
            release_name="my-service",
            chart="repo/chart",
            namespace="my-namespace",
            values_dict=values_with_secrets,
            version="1.0.0"
        )
```

## Workflow

### For GitHub Runners

1. Edit `k8s/quantierra-github-runners/values-{tier}.yaml` as needed
2. Keep `githubConfigSecret.github_token: "REDACTED"` in the file
3. Run `./scripts/deploy-k8s.py github-runners --tier {tier}`
4. Commit changes (REDACTED placeholder stays in git)

### For Other Services

1. Create values YAML with secret placeholders
2. Deploy using `helm` subcommand with `--inject-secret` flags
3. Commit values file with placeholders

## Benefits

✅ **Security**: Secrets never committed to git
✅ **Convenience**: No manual REDACTED replacement
✅ **Reusability**: Works for any Helm deployment
✅ **Safety**: Original files never modified
✅ **Visibility**: Dry-run shows exactly what will be deployed

## Examples

### Update and redeploy XL runners

```bash
# Edit the values file
vim k8s/quantierra-github-runners/values-xl.yaml

# Deploy with automatic secret injection
./scripts/deploy-k8s.py github-runners --tier xl

# Commit changes (REDACTED stays in git)
git add k8s/quantierra-github-runners/values-xl.yaml
git commit -m "feat(k8s): update XL runner resources"
```

### Deploy new service with secrets

```bash
./scripts/deploy-k8s.py helm my-api my-repo/api-chart \
  --namespace production \
  --values k8s/my-api/values.yaml \
  --inject-secret "prod/api/key:api.secretKey" \
  --inject-secret "prod/db/password:database.password" \
  --version 2.1.0
```

## Troubleshooting

### Error: secrets-print command not found

- Make sure you're in the nix dev shell: `nix develop` or `direnv allow`

### Error: Could not parse GITHUB_TOKEN from secret

- Check the secret file format in agenix
- Secret should contain `GITHUB_TOKEN=value` line

### Error: PyYAML required

- Install PyYAML: `pip install pyyaml`

### Dry run showing wrong values

- Check secret path is correct
- Check YAML path uses dot notation (e.g., `a.b.c` not `a.b[c]`)
