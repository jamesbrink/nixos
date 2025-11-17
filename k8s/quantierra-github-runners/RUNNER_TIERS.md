# GitHub Actions Runner Tier Configuration

## Runner Tiers and Node Placement

### Tier: selfhost-xl

- **Node Selector**: `gha-tier: selfhost-l` (runs on hal9000)
- **Resources**:
  - Requests: 8 CPU, 16Gi memory
  - Limits: 16 CPU, 32Gi memory
- **Labels**: quantierra-gha, linux, selfhost-xl
- **Replicas**: 1
- **Autoscaler**: min 1, max 2

### Tier: selfhost-l

- **Node Selector**: `gha-tier: selfhost-l` (runs on hal9000)
- **Resources**:
  - Requests: 1 CPU, 2Gi memory
  - Limits: 4 CPU, 8Gi memory
- **Labels**: quantierra-gha, linux, selfhost-l
- **Replicas**: 4
- **Autoscaler**: min 4, max 10

### Tier: selfhost-m

- **Node Selector**: `gha-tier: selfhost-m` (runs on alienware)
- **Resources**:
  - Requests: 1 CPU, 2Gi memory
  - Limits: 4 CPU, 8Gi memory
- **Labels**: quantierra-gha, linux, selfhost-m
- **Replicas**: 2
- **Autoscaler**: min 2, max 6

### Tier: selfhost-s

- **Node Selector**: `gha-tier: selfhost-s` (runs on n100 nodes)
- **Resources**:
  - Requests: 1 CPU, 2Gi memory
  - Limits: 2 CPU, 4Gi memory
- **Labels**: quantierra-gha, linux, selfhost-s
- **Replicas**: 4
- **Autoscaler**: min 4, max 8
- **Additional**: topology spread constraints to distribute across n100 nodes

## Node Labels (set via NixOS k3s module)

- **hal9000**: `gha-tier=selfhost-l`
- **alienware**: `gha-tier=selfhost-m`
- **n100-01/02/03/04**: `gha-tier=selfhost-s`

## GitHub Configuration

- **Organization**: quantierra
- **Runner Group**: quantierra-gha
- **Secret**: gha-controller-manager (contains GitHub PAT)
- **Common Settings**:
  - ephemeral: true
  - dockerdWithinRunnerContainer: false (uses sidecar)
  - image: ghcr.io/actions/actions-runner:2.329.0
