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

### If Helm gets `403 denied` from ghcr.io

The ARC charts are public, so a 403 is never a permissions problem — it means
Helm found a **stale credential** and sent it. GHCR rejects a dead token with
403 rather than falling back to anonymous, which makes it look like access was
denied.

Seen on halcyon 2026-08-25: the login keychain held a `ghcr.io` entry for the
`quantierra` account containing a revoked classic PAT, stored months earlier by
a manual `docker login`. Anonymous requests returned 200 while every Helm pull
returned 403.

Clearing the config files does **not** help — `--registry-config`,
`DOCKER_CONFIG` and `HELM_REGISTRY_CONFIG` only control the `auths` map in a
file, while the credential lives in the platform keychain and is fetched
through `docker-credential-osxkeychain`. Helm consults that helper even with
`credsStore` explicitly emptied.

Diagnose by comparing anonymous against the stored credential:

```bash
URL='https://ghcr.io/token?scope=repository%3Aactions%2Factions-runner-controller-charts%2Fgha-runner-scale-set%3Apull&service=ghcr.io'
curl -s -o /dev/null -w 'anon=%{http_code}\n' "$URL"          # expect 200
security find-internet-password -s ghcr.io | grep '"acct"'     # who is stored
```

Fix by replacing the entry with a current token rather than deleting it:

```bash
secrets-print jamesbrink/github-token | helm registry login ghcr.io \
  -u <github-username> --password-stdin
```

### kubectl cannot reach the cluster by its LAN name

`~/.kube/config` points at `hal9000.home.urandom.io` (10.70.100.206), which no
longer resolves to a reachable address; hal9000 is reached over Tailscale. The
API certificate has no Tailscale SAN, but it does cover `127.0.0.1`, so tunnel
rather than adding an SAN:

```bash
ssh -f -N -L 16443:127.0.0.1:6443 hal9000
ssh hal9000 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's#127.0.0.1:6443#127.0.0.1:16443#' > /tmp/kubeconfig-hal9000
export KUBECONFIG=/tmp/kubeconfig-hal9000
```

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
