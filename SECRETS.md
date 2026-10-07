# Secrets Management

Secrets are managed as a git submodule at `secrets/` (pointing to `git@github.com:jamesbrink/nix-secrets.git`).

## Prerequisites

1. Initialize the secrets submodule (if not already done):

   ```bash
   git submodule update --init secrets
   ```

2. Get the host's SSH host key:

   ```bash
   ssh <hostname> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub"
   ```

## Adding a New Host to Secrets

Replace `<hostname>` with your actual hostname (e.g., halcyon, bender, hal9000).

1. Navigate to the secrets submodule:

   ```bash
   cd secrets
   ```

2. Edit `secrets.nix` and add the host's public key:

   ```nix
   <hostname> = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... (your key here)";
   ```

3. Add `<hostname>` to all relevant `publicKeys` arrays in the file.

4. Re-encrypt all secrets with the new recipient:

   ```bash
   RULES=./secrets.nix agenix -r -i ~/.ssh/id_ed25519
   ```

5. Commit and push the submodule changes:

   ```bash
   git add -A
   git commit -m "Add <hostname> to age recipients"
   git push
   ```

6. Back in the main nixos repository, commit the updated submodule reference:

   ```bash
   cd ..
   git add secrets
   git commit -m "chore(secrets): update submodule"
   ```

## Required Secrets

The following secrets are expected for the jamesbrink user:

- `secrets/jamesbrink/aws/config.age`
- `secrets/jamesbrink/aws/credentials.age`

If these don't exist, create them from the secrets submodule:

```bash
cd secrets
agenix -e jamesbrink/aws/config.age
agenix -e jamesbrink/aws/credentials.age
```

## Claude Code profiles

`claude-profile` is available in Bash and Zsh. Select `primary` / `1`,
`secondary` / `2`, or `quantierra` / `3`; all three use Claude Code OAuth
tokens. `api` selects the separate Anthropic API key, `none` clears active
credentials, and `status` shows the active profile. Shell defaults are unchanged:
halcyon starts without credentials; other hosts use secondary when available.

- `secrets/jamesbrink/claude-primary.age`
- `secrets/jamesbrink/claude-secondary.age`
- `secrets/jamesbrink/claude-quantierra.age`

All three use the `allKeys` recipients in `secrets/secrets.nix`. Darwin
(including slim profiles) and Linux deploy them as owner-only (`0600`) secrets
and generate matching token files in `~/.config/environment.d/`.

To populate or rotate the Quantierra secret, enter the account's Claude Code
OAuth token (not an Anthropic API key):

```bash
scripts/secrets-edit.sh jamesbrink/claude-quantierra
```

Save only the token as the secret contents. Commit the secret and its recipient
rule in the secrets submodule, then update the parent repository's submodule
reference along with the profile wiring. Rebuild/deploy the target host after
populating or rotating the token, open a new shell, then run:

```bash
claude-profile quantierra
claude-profile status
```

## Deployment

After setting up secrets, you can deploy the configuration:

```bash
deploy <hostname>
```

Or test first:

```bash
deploy-test <hostname>
```

## Cert-Manager

- Secret path: `secrets/global/aws/cert-credentials-secret.age`
  - Contains `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` for Route53 DNS01 challenges.
- The `k3s-cert-manager-route53-secret` service on `hal9000` reads this file and creates/updates the `route53-credentials` secret inside the `cert-manager` namespace.
- Rotate the key via `scripts/secrets-edit.sh global/aws/cert-credentials-secret` followed by `deploy hal9000` to refresh in-cluster credentials.
