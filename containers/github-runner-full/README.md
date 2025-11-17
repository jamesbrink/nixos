# GitHub Actions Runner - Full Development Image

Custom GitHub Actions runner image extending the official `ghcr.io/actions/actions-runner:latest` with a comprehensive suite of development tools.

## Included Tools

### Languages & Runtimes

- **Python**: 3.11, 3.12, 3.13 (default: 3.13, with pip, uv, poetry, virtualenv, pytest, black, ruff, mypy)
  - **libpostal**: C library + Python bindings for address parsing/normalization (master branch)
- **Node.js**: v20 LTS (with npm, yarn, pnpm, typescript, eslint, prettier)
- **Go**: Latest stable
- **Rust**: Stable toolchain (with cargo, clippy, rustfmt)
- **Ruby**: Latest stable (with bundler)
- **Java**: OpenJDK 17 LTS (with Maven, Gradle)
- **.NET**: 8.0 LTS SDK
- **Nix**: Multi-user installation

### Infrastructure & Cloud CLIs

- **Docker**: CLI (for use with DinD sidecar)
- **Docker Compose**: Latest
- **kubectl**: v1.31
- **Helm**: Latest v3
- **Terraform**: Latest
- **AWS CLI**: v2
- **Azure CLI**: Latest
- **Google Cloud SDK**: Latest

### Development Tools

- **GitHub CLI**: Latest
- **PostgreSQL**: Client (psql) + development libraries (libpq-dev)
- **Poppler Utils**: PDF manipulation tools (pdftotext, pdfimages, etc.)
- Build essentials (gcc, make, etc.)
- Git, curl, wget, jq
- Common libraries (OpenSSL, libffi, zlib, etc.)

## Automated Builds

This image is **automatically built and published** via GitHub Actions when changes are pushed to the `main` branch.

- **Workflow**: `.github/workflows/build-runner-image.yaml`
- **Triggers**:
  - Push to `main` branch (changes to `containers/github-runner-full/**`)
  - Manual workflow dispatch
- **Registry**: `ghcr.io/jamesbrink/github-runner-full`
- **Visibility**: Public (automatically set by workflow)

### Automated Upstream Updates

A scheduled workflow checks daily for updates to the upstream `ghcr.io/actions/actions-runner` base image:

- **Workflow**: `.github/workflows/check-upstream-runner.yaml`
- **Schedule**: Daily at 6 AM UTC
- **Action**: Creates a PR when upstream image is updated
- **Benefits**: Automatic tracking of security patches and new features

See `CI-CD.md` for details.

**Available tags**:

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit SHA
- `main` - Main branch latest

**Pull the image**:

```bash
docker pull ghcr.io/jamesbrink/github-runner-full:latest
```

## Building Locally

**Note**: This image is built for `linux/amd64` (x86_64) as that's what GitHub Actions runners use.

```bash
# Using the build script (recommended - handles cross-platform)
./build.sh

# Or manually with buildx
docker buildx build --platform linux/amd64 --load -t ghcr.io/jamesbrink/github-runner-full:latest .

# Build with specific tag
docker buildx build --platform linux/amd64 --load -t ghcr.io/jamesbrink/github-runner-full:v1.0.0 .
```

**Apple Silicon / ARM64 Users**: The build script automatically handles cross-compilation. The verification step in the Dockerfile is disabled for local builds since x86_64 binaries can't run during ARM64 builds. GitHub Actions CI will verify the build on amd64.

## Manual Registry Push

Only needed if you want to push manually (automated via GitHub Actions):

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u jamesbrink --password-stdin

# Push the image
docker push ghcr.io/jamesbrink/github-runner-full:latest

# Set package to public (if needed)
./set-package-public.sh
```

## Using in GitHub Actions Runner Scale Sets

Update your values files to use this custom image:

```yaml
# values-xl.yaml, values-l.yaml, etc.
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/jamesbrink/github-runner-full:latest
        # ... rest of config
```

Then upgrade your Helm releases:

```bash
helm upgrade arc-runner-set-xl \
  --namespace github-runners \
  -f values-xl.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

## Image Size

This image is significantly larger than the base runner image due to all the included tools. Expect ~7-10GB depending on layers.

**Size breakdown:**

- Base image + languages/tools: ~5-6GB
- libpostal data: ~1.5GB
- Cloud SDKs + other tools: ~2-3GB

## Notes

### libpostal Data Files

The libpostal address parsing data (~1.5GB) is **pre-downloaded and baked into the image** at `/usr/local/share/libpostal`. This means your workflows can use libpostal immediately without any initial download delay.

The data is downloaded during the image build using:

```bash
/usr/local/bin/libpostal_data download all /usr/local/share/libpostal
```

This approach was adopted from the `quantierra/dealflow-api` production Dockerfile to ensure consistent, fast startup times.

## Customization

Edit the Dockerfile to:

- Add/remove languages
- Change version pins
- Add project-specific tools
- Pre-download libpostal data files
- Optimize for your specific workflow needs

## Verification

After building, verify all tools are present:

```bash
docker run --rm ghcr.io/jamesbrink/github-runner-full:latest bash -c "
  python3 --version && \
  uv --version && \
  python3 -c 'import postal; print(\"libpostal OK\")' && \
  node --version && \
  go version && \
  rustc --version && \
  docker --version && \
  psql --version && \
  kubectl version --client
"
```
