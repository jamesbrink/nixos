# K3s Kubernetes Module
# Single-node k3s cluster with GPU support, Traefik ingress, and RBAC
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.k3s-cluster;

  # Generate user namespace manifests
  userNamespacesYaml = pkgs.writeText "user-namespaces.yaml" (
    concatMapStringsSep "\n---\n" (user: ''
      apiVersion: v1
      kind: Namespace
      metadata:
        name: ${user}
        labels:
          owner: ${user}
          managed-by: nixos
    '') cfg.users
  );

  # Generate cluster admin RBAC
  clusterAdminsYaml = pkgs.writeText "cluster-admins.yaml" (
    concatMapStringsSep "\n---\n" (admin: ''
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: ${admin}-cluster-admin
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cluster-admin
      subjects:
      - kind: User
        name: ${admin}
        apiGroup: rbac.authorization.k8s.io
    '') cfg.admins
  );

  # Generate namespace admin RBAC
  namespaceAdminsYaml = pkgs.writeText "namespace-admins.yaml" (
    concatMapStringsSep "\n---\n" (user: ''
      apiVersion: rbac.authorization.k8s.io/v1
      kind: RoleBinding
      metadata:
        name: ${user}-namespace-admin
        namespace: ${user}
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: admin
      subjects:
      - kind: User
        name: ${user}
        apiGroup: rbac.authorization.k8s.io
    '') cfg.users
  );

  # Helper function to generate kubeconfig for users
  generateUserKubeconfigs = pkgs.writeShellScript "generate-user-kubeconfigs" ''
    set -euo pipefail

    echo "Waiting for k3s API server..."
    until ${pkgs.kubectl}/bin/kubectl get ns 2>/dev/null; do
      sleep 2
    done
    echo "✓ k3s API server is ready"

    USERS=(${concatStringsSep " " cfg.users})
    for user in "''${USERS[@]}"; do
      USER_HOME=$(getent passwd "$user" 2>/dev/null | cut -d: -f6 || true)

      if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
        echo "⚠ Skipping $user: home directory not found"
        continue
      fi

      mkdir -p "$USER_HOME/.kube"
      KUBECONFIG_PATH="$USER_HOME/.kube/config"

      ${pkgs.kubectl}/bin/kubectl config view --raw > /tmp/kubeconfig-temp-$user

      ${pkgs.kubectl}/bin/kubectl --kubeconfig=/tmp/kubeconfig-temp-$user config set-context "$user-context" \
        --cluster=default \
        --user=default \
        --namespace="$user" >/dev/null

      ${pkgs.kubectl}/bin/kubectl --kubeconfig=/tmp/kubeconfig-temp-$user config use-context "$user-context" >/dev/null

      mv /tmp/kubeconfig-temp-$user "$KUBECONFIG_PATH"
      chown "$user:users" "$KUBECONFIG_PATH"
      chmod 600 "$KUBECONFIG_PATH"

      echo "✓ Generated kubeconfig for $user (namespace: $user)"
    done

    echo "✓ All user kubeconfigs generated successfully"
  '';

in
{
  options.services.k3s-cluster = {
    enable = mkEnableOption "k3s cluster with optional GPU support";

    role = mkOption {
      type = types.enum [
        "server"
        "agent"
      ];
      default = "server";
      description = "K3s role: 'server' for master node or 'agent' for worker node";
    };

    serverUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "K3s server URL for agent nodes (e.g., https://server:6443)";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Users to create namespaces for";
    };

    admins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Users with cluster-admin access";
    };

    hostname = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Hostname for TLS SANs";
    };

    domain = mkOption {
      type = types.str;
      default = config.networking.domain or "local";
      description = "Domain for TLS SANs and ingress";
    };

    maxPods = mkOption {
      type = types.int;
      default = 500;
      description = "Maximum pods per node";
    };

    storagePoolDataset = mkOption {
      type = types.str;
      default = "storage-fast/k3s";
      description = "ZFS dataset for k3s storage (must be created manually)";
    };

    storageMountpoint = mkOption {
      type = types.str;
      default = "/var/lib/rancher";
      description = "Mountpoint for k3s storage";
    };

    enableTraefik = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Traefik ingress controller";
    };

    enableGpuSupport = mkOption {
      type = types.bool;
      default = false;
      description = "Enable NVIDIA GPU support (requires NVIDIA drivers)";
    };
  };

  config = mkIf cfg.enable {
    # K3s service configuration
    services.k3s = {
      enable = true;
      role = cfg.role;

      # Use secure token from agenix
      tokenFile = config.age.secrets.k3s-token.path;

      # Server URL for agent nodes
      serverAddr = mkIf (cfg.role == "agent") cfg.serverUrl;

      # Containerd config for NVIDIA GPU support
      containerdConfigTemplate = mkIf cfg.enableGpuSupport ''
        version = 2
        root = "/var/lib/rancher/k3s/agent/containerd"
        state = "/run/k3s/containerd"

        [grpc]
          address = "/run/k3s/containerd/containerd.sock"

        [plugins."io.containerd.internal.v1.opt"]
          path = "/var/lib/rancher/k3s/agent/containerd"

        [plugins."io.containerd.grpc.v1.cri"]
          stream_server_address = "127.0.0.1"
          stream_server_port = "10010"
          enable_selinux = false
          enable_unprivileged_ports = true
          enable_unprivileged_icmp = true
          device_ownership_from_security_context = false
          sandbox_image = "rancher/mirrored-pause:3.6"
          enable_cdi = true
          cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]

        [plugins."io.containerd.grpc.v1.cri".containerd]
          snapshotter = "overlayfs"
          disable_snapshot_annotations = true

        [plugins."io.containerd.grpc.v1.cri".cni]
          bin_dir = "/var/lib/rancher/k3s/data/cni"
          conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          runtime_type = "io.containerd.runc.v2"
          privileged_without_host_devices = false

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
          BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime"
          SystemdCgroup = true

        [plugins."io.containerd.grpc.v1.cri".registry]
          config_path = "/var/lib/rancher/k3s/agent/etc/containerd/certs.d"
      '';

      # K3s flags
      extraFlags =
        if cfg.role == "server" then
          [
            "--write-kubeconfig-mode=644"
            "--disable=traefik"
            "--tls-san=${cfg.hostname}"
            "--tls-san=${cfg.hostname}.${cfg.domain}"
            "--kubelet-arg=max-pods=${toString cfg.maxPods}"
            "--kubelet-arg=kube-api-burst=250"
            "--kubelet-arg=kube-api-qps=150"
            "--kube-apiserver-arg=max-requests-inflight=800"
            "--kube-apiserver-arg=max-mutating-requests-inflight=400"
          ]
          ++ optional (
            config.networking.primaryIPAddress or null != null
          ) "--tls-san=${config.networking.primaryIPAddress}"
        else
          [
            # Agent-specific flags
            "--kubelet-arg=max-pods=${toString cfg.maxPods}"
          ];

      # User management manifests (only on server)
      manifests = mkIf (cfg.role == "server") (mkMerge [
        (mkIf (cfg.users != [ ]) {
          user-namespaces = {
            target = "user-namespaces.yaml";
            source = userNamespacesYaml;
          };
          namespace-admins = {
            target = "namespace-admins.yaml";
            source = namespaceAdminsYaml;
          };
        })

        (mkIf (cfg.admins != [ ]) {
          cluster-admins = {
            target = "cluster-admins.yaml";
            source = clusterAdminsYaml;
          };
        })

        # NVIDIA GPU support
        (mkIf cfg.enableGpuSupport {
          nvidia-runtime-class = {
            target = "nvidia-runtime-class.yaml";
            source = ./k3s-manifests/nvidia-runtime-class.yaml;
          };
          nvidia-device-plugin = {
            target = "nvidia-device-plugin.yaml";
            source = ./k3s-manifests/nvidia-device-plugin.yaml;
          };
        })

        # Traefik ingress controller via HelmChart manifest
        (mkIf cfg.enableTraefik {
          traefik-helmchart = {
            enable = true;
            content = {
              apiVersion = "helm.cattle.io/v1";
              kind = "HelmChart";
              metadata = {
                name = "traefik";
                namespace = "kube-system";
              };
              spec = {
                # Reference the chart via Kubernetes API server (uses local file)
                chart = "https://%{KUBERNETES_API}%/static/charts/traefik.tgz";
                targetNamespace = "traefik";
                createNamespace = true;
                valuesContent = ''
                  deployment:
                    replicas: 1

                  service:
                    type: LoadBalancer

                  ports:
                    web:
                      port: 80
                      exposedPort: 80
                    websecure:
                      port: 443
                      exposedPort: 443

                  providers:
                    kubernetesCRD:
                      enabled: true
                    kubernetesIngress:
                      enabled: true

                  logs:
                    general:
                      level: INFO
                    access:
                      enabled: false

                  resources:
                    requests:
                      cpu: 100m
                      memory: 128Mi
                    limits:
                      cpu: 500m
                      memory: 512Mi
                '';
              };
            };
          };
        })
      ]);
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [ 6443 ];
      trustedInterfaces = mkAfter [
        "cni0"
        "flannel.1"
      ];
    };

    # Global kubeconfig access
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # System packages
    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
    ];

    # User kubeconfig generation service (server only)
    systemd.services.k3s-generate-user-kubeconfigs = mkIf (cfg.role == "server" && cfg.users != [ ]) {
      description = "Generate per-user kubeconfig files";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
      };
      script = ''
        ${generateUserKubeconfigs}
      '';
    };

    # Traefik ingress controller via k3s Helm controller (server only)
    # Fetch Traefik chart at build time and place in static charts directory
    services.k3s.charts = mkIf (cfg.role == "server" && cfg.enableTraefik) {
      traefik = pkgs.fetchurl {
        url = "https://traefik.github.io/charts/traefik/traefik-37.3.0.tgz";
        sha256 = "sha256-Xgn3PJ7yCYK1h2nandqsDuSYQapIIISxprCKyZb0n/s=";
      };
    };
  };
}
