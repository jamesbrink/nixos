# Secrets Management for Halcyon (macOS)

## Prerequisites

1. Ensure you have SSH access to the secrets repository:

   ```bash
   git clone git@github.com:jamesbrink/nix-secrets.git ../nix-secrets
   ```

2. Get Halcyon's SSH host key:

   ```bash
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

## Adding Halcyon to Secrets

1. Navigate to the secrets repository:

   ```bash
   cd ../nix-secrets
   ```

2. Edit `secrets.nix` and add Halcyon's public key:

   ```nix
   halcyon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... (your key here)";
   ```

3. Add `halcyon` to all relevant `publicKeys` arrays in the file.

4. Re-encrypt all secrets with the new recipient:

   ```bash
   cd ../nix-secrets
   RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519
   ```

5. Commit and push changes:

   ```bash
   git add -A
   git commit -m "Add halcyon to age recipients"
   git push
   ```

6. Back in the main nixos repository, update the secrets input:

   ```bash
   cd ~/Projects/jamesbrink/nixos
   nix flake lock --update-input secrets
   ```

## Required Secrets

The following secrets are expected for the jamesbrink user:

- `secrets/jamesbrink/aws/config.age`
- `secrets/jamesbrink/aws/credentials.age`

If these don't exist in the secrets repository, create them:

```bash
cd ../nix-secrets
agenix -e secrets/jamesbrink/aws/config.age
agenix -e secrets/jamesbrink/aws/credentials.age
```

## Deployment

After setting up secrets, you can deploy the configuration:

```bash
deploy halcyon
```

Or test first:

```bash
deploy-test halcyon
```

## Quantierra GitHub Runners

- Secret path: `secrets/jamesbrink/github/quantierra-runner-token.age`
  - Store a PAT with `admin:org`, `repo`, `workflow`, and `read:org`.
  - Format: single line `GITHUB_TOKEN=<value>`.
- Sync into Kubernetes via:

  ```bash
  ./scripts/deploy-quantierra-github-runners.sh --sync-secret
  ```

- The script creates/updates the `gha-controller-manager` secret in the `github-runners` namespace so ARC and the runner scale set can register with the `quantierra` org.

## Cert-Manager

- Secret path: `secrets/global/aws/cert-credentials-secret.age`
  - Contains `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` for Route53 DNS01 challenges.
- The `k3s-cert-manager-route53-secret` service on `hal9000` reads this file and creates/updates the `route53-credentials` secret inside the `cert-manager` namespace.
- Rotate the key via `scripts/secrets-edit.sh global/aws/cert-credentials-secret` followed by `deploy halcyon` to refresh in-cluster credentials.
