# CI/CD Setup for GitHub Runner Image

## Overview

Automated Docker image build and publish pipeline using GitHub Actions.

## Workflows

### 1. Build and Push Image

**File**: `.github/workflows/build-runner-image.yaml`

**Triggers**:

- Push to `main` branch affecting:
  - `containers/github-runner-full/**`
  - `.github/workflows/build-runner-image.yaml`
- Pull requests (builds but doesn't push)
- Manual workflow dispatch

**Runner**: `ubuntu-latest` (official GitHub-hosted runner)

**Registry**: `ghcr.io/jamesbrink/github-runner-full` (GitHub Container Registry)

**Permissions**:

- `contents: read` - Checkout repository
- `packages: write` - Push to GHCR

## Image Tags

The workflow automatically tags images:

- `latest` - Latest build from main branch (only on main)
- `main` - Main branch latest
- `main-<commit-sha>` - Specific commit (e.g., `main-abc1234`)
- PR builds get tagged with PR number (but not pushed)

## Build Features

- **BuildKit caching**: Uses GitHub Actions cache for faster builds
- **Platform**: `linux/amd64`
- **Automatic public visibility**: Workflow sets package to public after push
- **Build logs**: Available in Actions tab

### 2. Check Upstream Runner Image

**File**: `.github/workflows/check-upstream-runner.yaml`

**Purpose**: Automatically detect when GitHub releases a new `actions-runner` base image

**Triggers**:

- Scheduled: Daily at 6 AM UTC
- Manual workflow dispatch

**What it does**:

1. Checks the digest of `ghcr.io/actions/actions-runner:latest`
2. Compares with the current base image in the Dockerfile
3. If changed, creates a PR with:
   - Updated Dockerfile pinned to new digest
   - Details about the upstream changes
   - Labels for dependency tracking

**Benefits**:

- Stay up-to-date with upstream security patches
- Automated tracking of base image updates
- PR-based workflow allows review before rebuilding
- Digest pinning ensures reproducible builds

## First Run Setup

When the workflow runs for the first time:

1. Creates the package in GHCR
2. Pushes the image
3. Attempts to set visibility to public
4. If auto-public fails, run manually: `./set-package-public.sh`

## Package URL

Once published, the image will be available at:

- **Package**: <https://github.com/users/jamesbrink/packages/container/package/github-runner-full>
- **Pull command**: `docker pull ghcr.io/jamesbrink/github-runner-full:latest`

## Monitoring Builds

View build status and logs:

```bash
# List recent workflow runs
gh run list --workflow=build-runner-image.yaml

# Watch latest run
gh run watch

# View logs for a specific run
gh run view <run-id> --log
```

## Manual Trigger

Trigger a build manually:

```bash
gh workflow run build-runner-image.yaml
```

## Debugging Build Failures

If a build fails:

1. Check the Actions tab: <https://github.com/jamesbrink/nixos/actions>
2. Review build logs for the specific step that failed
3. Test locally: `cd containers/github-runner-full && docker build .`
4. Fix the issue and push to trigger a new build

## Security

- Uses `GITHUB_TOKEN` (automatically provided by GitHub Actions)
- No manual secrets required
- Token has minimal required permissions (read repo, write packages)
- Public image means anyone can pull without authentication

## Build Time

Expected build time: **20-35 minutes** longer on first build due to:

- Compiling libpostal from source (~5 min)
- **Downloading libpostal data (~1.5GB, ~5-10 min)**
- Installing multiple language runtimes (~5 min)
- Downloading large packages (Go, .NET, cloud CLIs, ~5-10 min)

Subsequent builds will be faster due to layer caching. The libpostal data download layer is cached, so it only happens once unless the libpostal installation step changes.
