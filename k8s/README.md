# Kubernetes Assets

This tree holds every manifest or Helm chart that needs to be deployed to clusters that are not managed directly by NixOS. Keep each workload in its own subdirectory and include a brief README alongside rendered manifests so reviewers can trace what is being installed.

Current layout:

| Path                             | Purpose                                                                                                     |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `k8s/quantierra-github-runners/` | Home for the Quantierra GitHub Actions runner deployment (Helm values, rendered manifests, helper scripts). |

Common pattern:

1. Create a `<workload>/charts/` directory that stores chart-specific overrides (`values.<env>.yaml`, secrets references, etc.).
2. Render manifests into `<workload>/manifests/` so they can be reviewed and applied via `kubectl apply -k` or `kubectl apply -f`.
3. Document any automation and secrets the workload needs (token names, GitHub App IDs, etc.) in the workload README and `SECRETS.md`.

Use `nix develop` to access helper binaries (e.g., `helm`, `kubectl`, `sops/age`). Keep kubeconfigs encrypted in `secrets/` and sync them to hosts via existing agenix wiring.
