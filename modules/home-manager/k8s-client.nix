# Kubernetes client configuration
# Sets up kubectl/helm access to k3s clusters
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.k8s-client;

  # Generate kubeconfig for hal9000 cluster
  hal9000KubeConfig = pkgs.writeText "hal9000-kubeconfig" ''
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        server: https://hal9000.home.urandom.io:6443
        insecure-skip-tls-verify: true
      name: hal9000
    contexts:
    - context:
        cluster: hal9000
        user: admin
        namespace: jamesbrink
      name: hal9000
    - context:
        cluster: hal9000
        user: admin
        namespace: default
      name: hal9000-default
    current-context: hal9000
    users:
    - name: admin
      user:
        client-certificate: /etc/rancher/k3s/k3s.yaml
        client-key: /etc/rancher/k3s/k3s.yaml
  '';

in
{
  options.programs.k8s-client = {
    enable = mkEnableOption "Kubernetes client configuration";

    clusters = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            server = mkOption {
              type = types.str;
              description = "Kubernetes API server URL";
            };
            namespace = mkOption {
              type = types.str;
              default = "default";
              description = "Default namespace for this cluster";
            };
            insecureSkipTlsVerify = mkOption {
              type = types.bool;
              default = false;
              description = "Skip TLS verification";
            };
          };
        }
      );
      default = { };
      description = "Kubernetes clusters to configure";
    };
  };

  config = mkIf cfg.enable {
    # Install kubectl tools
    home.packages = with pkgs; [
      kubectx # Provides both kubectx and kubens
    ];

    # Create .kube directory
    home.file.".kube/.keep".text = "";

    # Shell aliases for kubectl
    programs.zsh.shellAliases = {
      k = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get svc";
      kgn = "kubectl get nodes";
      kga = "kubectl get all";
      kdp = "kubectl describe pod";
      kl = "kubectl logs";
      kx = "kubectx";
      kn = "kubens";
    };

    programs.bash.shellAliases = {
      k = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get svc";
      kgn = "kubectl get nodes";
      kga = "kubectl get all";
      kdp = "kubectl describe pod";
      kl = "kubectl logs";
      kx = "kubectx";
      kn = "kubens";
    };

    # Environment variables
    home.sessionVariables = {
      KUBECONFIG = "$HOME/.kube/config";
    };

    # Auto-setup kubeconfig for local k3s cluster
    home.activation.setupLocalK3s = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      K3S_CONFIG="/etc/rancher/k3s/k3s.yaml"
      USER_CONFIG="$HOME/.kube/config"

      # If this host runs k3s and user config doesn't exist or is empty, set it up
      if [ -f "$K3S_CONFIG" ] && ([ ! -f "$USER_CONFIG" ] || [ ! -s "$USER_CONFIG" ]); then
        $DRY_RUN_CMD mkdir -p "$HOME/.kube"

        # Copy k3s config and update server address
        if [ -z "$DRY_RUN_CMD" ]; then
          # k3s.yaml has mode 644, no sudo needed
          FQDN=$(${pkgs.inetutils}/bin/hostname --fqdn 2>/dev/null || echo "localhost")
          cat "$K3S_CONFIG" | \
            ${pkgs.gnused}/bin/sed 's|https://127.0.0.1:6443|https://'"$FQDN"':6443|g' > "$USER_CONFIG"
          chmod 600 "$USER_CONFIG"

          # Set default namespace to user's namespace
          ${pkgs.kubectl}/bin/kubectl config set-context --current --namespace=${config.home.username} 2>/dev/null || true

          echo "✓ Configured kubectl for local k3s cluster (namespace: ${config.home.username})"
        fi
      fi
    '';

    # Setup script to merge hal9000 context into existing kubeconfig
    home.file.".local/bin/k8s-setup-hal9000" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        echo "Setting up kubectl access to hal9000 k3s cluster..."

        # Verify k3s is accessible on hal9000
        if ! ssh hal9000 "test -f /etc/rancher/k3s/k3s.yaml"; then
          echo "Error: k3s not running on hal9000 or kubeconfig not found"
          exit 1
        fi

        # Create .kube directory if needed
        mkdir -p ~/.kube

        # Backup existing config if it exists
        if [ -f ~/.kube/config ]; then
          cp ~/.kube/config ~/.kube/config.backup.$(date +%Y%m%d-%H%M%S)
          echo "✓ Backed up existing kubeconfig"
        fi

        # Fetch hal9000 kubeconfig to temp file
        TMP_CONFIG=$(mktemp)
        ssh hal9000 "sudo cat /etc/rancher/k3s/k3s.yaml" | \
          sed 's/127.0.0.1/hal9000.home.urandom.io/g' > "$TMP_CONFIG"

        # Extract credentials and cluster info from hal9000 kubeconfig
        CERT_DATA=$(${pkgs.yq-go}/bin/yq eval '.clusters[0].cluster.certificate-authority-data' "$TMP_CONFIG")
        CLIENT_CERT=$(${pkgs.yq-go}/bin/yq eval '.users[0].user.client-certificate-data' "$TMP_CONFIG")
        CLIENT_KEY=$(${pkgs.yq-go}/bin/yq eval '.users[0].user.client-key-data' "$TMP_CONFIG")

        # Merge hal9000 cluster into existing config (preserves other clusters)
        ${pkgs.kubectl}/bin/kubectl config set-cluster hal9000 \
          --server=https://hal9000.home.urandom.io:6443 \
          --certificate-authority-data="$CERT_DATA" \
          --embed-certs=true

        ${pkgs.kubectl}/bin/kubectl config set-credentials hal9000-admin \
          --client-certificate-data="$CLIENT_CERT" \
          --client-key-data="$CLIENT_KEY" \
          --embed-certs=true

        ${pkgs.kubectl}/bin/kubectl config set-context hal9000 \
          --cluster=hal9000 \
          --user=hal9000-admin \
          --namespace=jamesbrink

        ${pkgs.kubectl}/bin/kubectl config set-context hal9000-default \
          --cluster=hal9000 \
          --user=hal9000-admin \
          --namespace=default

        rm "$TMP_CONFIG"
        chmod 600 ~/.kube/config

        echo "✓ hal9000 cluster added to kubeconfig"
        echo "  Contexts: hal9000 (namespace: jamesbrink), hal9000-default (namespace: default)"
        echo ""
        echo "Switch to hal9000: kubectx hal9000"
        echo "Test with: kubectl get nodes"
      '';
    };

    # Helper script to switch clusters
    home.file.".local/bin/k8s-use-cluster" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [ $# -eq 0 ]; then
          echo "Usage: k8s-use-cluster <cluster-name>"
          echo ""
          echo "Available clusters:"
          ${pkgs.kubectl}/bin/kubectl config get-contexts -o name
          exit 1
        fi

        ${pkgs.kubectl}/bin/kubectl config use-context "$1"
        echo "Switched to cluster: $1"
      '';
    };
  };
}
