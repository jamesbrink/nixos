# utensils GitHub Actions Runners

Self-hosted runner scale sets for the [`utensils`](https://github.com/utensils)
organization, primarily to carry [`utensils/mold`](https://github.com/utensils/mold)'s
CI, which is heavy (Rust workspace with 670+ tests, plus bun builds — 6–25 min per
build on this hardware).

Shares the ARC controller in `arc-systems` with the quantierra and urandomio
runners. Runner pods land in the `github-runners` namespace.

## Runner Tiers

| Tier | Scale set | Labels | Requests | Limits | Use case |
| ---- | --------- | ------ | -------- | ------ | -------- |
| `l` | `utensils-l` | `utensils-l`, `selfhost-l` | 2 cpu / 4Gi | 8 cpu / 16Gi | Lint, docs, bun/web builds |
| `xl` | `utensils-xl` | `utensils-xl`, `selfhost-xl` | 8 cpu / 16Gi | 20 cpu / 40Gi | Full Rust workspace + test suite |

Both tiers use `minRunners: 0` so nothing is reserved while idle.

### Why these numbers

hal9000 is the only `Ready` node in the cluster (32 cpu / 62Gi) **and** runs the
mold server, which owns the GPU. `maxRunners` is capped at 2 for `xl` so a CI
burst cannot starve the service it is building. Raise it only after confirming
headroom with `kubectl describe node hal9000`.

`xl` also reserves ephemeral storage — a full Rust + bun build tree is large and
an unbounded runner will fill the node's writable layer.

## Node Placement

Both tiers pin `nodeSelector: gha-tier=selfhost-l`, which resolves to hal9000.

> The other cluster nodes (`alienware`, `derp`, `n100-01..04`) have been
> `NotReady` since April 2026. Pods scheduled there keep reporting `Running`
> while doing nothing, which is how the ARC controller and its listeners went
> silently dead. Do not remove the nodeSelector until those nodes are back.

## Authentication (GitHub App)

Unlike quantierra/urandomio, which use classic PATs, utensils authenticates with
a GitHub App: the secrets do not expire, are scoped to the org, and are not tied
to a personal account.

### 1. Create the App

<https://github.com/organizations/utensils/settings/apps/new>

- **Permissions** → Organization: `Self-hosted runners: Read and write`
- **Webhook** → uncheck **Active**
- Homepage URL is required but never validated
- Generate a private key (`.pem`), note the **App ID**

### 2. Install it on the org

Creating an App is not installing it. Install to `utensils` (all repos, or just
`mold`), then read the **Installation ID** from the URL of
`https://github.com/organizations/utensils/settings/installations/<ID>`.

### 3. Store all three values in agenix

```bash
secrets-edit jamesbrink/github/utensils-app-id               # e.g. 1234567
secrets-edit jamesbrink/github/utensils-app-installation-id  # e.g. 89012345
secrets-edit jamesbrink/github/utensils-app-private-key      # full .pem, BEGIN/END included
```

`deploy-k8s.py` injects all three into `githubConfigSecret` at deploy time, so
they never land in these values files.

## Deploy

```bash
# Shared controller (pinned to hal9000) — run once, and after any ARC bump
./scripts/deploy-k8s.py github-runners --org utensils --controller

# Runner tiers
./scripts/deploy-k8s.py github-runners --org utensils            # both tiers
./scripts/deploy-k8s.py github-runners --org utensils --tier xl  # one tier
```

Chart version is pinned by `GitHubRunnersDeployer.VERSION` in
`scripts/deploy-k8s.py`; the controller tracks the same version.

## Using them from a workflow

Not yet wired into mold's CI. When you are ready, target the label:

```yaml
jobs:
  test:
    runs-on: utensils-xl
```

For a hosted/self-hosted fallback, resolve the label in a picker job and use
`runs-on: ${{ needs.pick-runner.outputs.label }}` — `runs-on` labels are ANDed,
so there is no native OR/fallback.

## Monitoring

```bash
kubectl get autoscalingrunnersets -n github-runners
kubectl get pods -n github-runners -l app.kubernetes.io/instance=arc-runner-set-utensils-xl
gh api orgs/utensils/actions/runners --jq '.runners[] | {name, status, busy}'
```
