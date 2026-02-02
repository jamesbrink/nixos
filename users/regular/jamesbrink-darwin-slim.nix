# Slim Darwin user configuration for headless/SSH-focused systems
# Includes devops tools and secrets, but no desktop apps
# Uses same shell/nvim config as jamesbrink-darwin.nix
{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

{
  imports = [
    # Shared user config (includes shell, nvim, git, ssh config)
    ./jamesbrink-shared.nix
  ];

  # Darwin user configuration
  users.users.jamesbrink = {
    name = "jamesbrink";
    home = "/Users/jamesbrink";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # SSH public keys for user jamesbrink
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmcoMbMstPPKsGH0oQLv8N6WgDSt8jvqcXpPfNkzAMq jamesbrink@bender.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArPfE2X8THR73peLxwMfd4uCXH8A3moM/T1l+HvgDva" # ViteTunnel
      # System keys
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARkb1kXdTi41j9j9JLPtY1+HxskjrSCkqyB5Dx0vcqj root@Alienware15R4"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkFHSY+3XcW54uu4POE743wYdh4+eGIR68O8121X29m root@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRNDnoVLI8Zy9YjOkHQuX6m9f9EzW8W2lYxnoGDjXtM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSf4Qft9nUD2gRDeJVkogYKY7PQvhlnD+kjFKgro3r"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKlaSFMo6Wcm5oZu3ABjPY4Q+INQBlVwxVktjfz66oI root@n100-04"
    ];
  };

  # Home-manager backup extension
  home-manager.backupFileExtension = "backup";

  # Extend home-manager configuration (jamesbrink-shared.nix provides the base)
  home-manager.users.jamesbrink =
    { pkgs, lib, ... }:
    {
      _module.args.inputs = inputs;

      # Disable Alacritty on darwin-slim (no GUI needed)
      programs.alacritty.enable = lib.mkForce false;

      # Override update alias for this host
      programs.zsh.shellAliases.update = lib.mkForce "darwin-rebuild switch --flake ~/Projects/jamesbrink/nixos#bender";
    };

  # Age configuration - identity paths for secrets decryption
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/Users/jamesbrink/.ssh/id_ed25519"
  ];

  # Age secrets
  age.secrets."aws-config" = {
    file = "${secretsPath}/jamesbrink/aws/config.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."aws-credentials" = {
    file = "${secretsPath}/jamesbrink/aws/credentials.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."github-token" = {
    file = "${secretsPath}/jamesbrink/github-token.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."pypi-key" = {
    file = "${secretsPath}/jamesbrink/pypi-key.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."hal9000-kubeconfig" = {
    file = "${secretsPath}/jamesbrink/k8s/hal9000-kubeconfig.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  # NFS mounts and secrets setup
  system.activationScripts.preActivation.text = ''
        # Clean up old home-manager backup files
        echo "Cleaning up old home-manager backup files..."
        sudo -u jamesbrink find /Users/jamesbrink/.config -name "*.backup" -type f -delete 2>/dev/null || true
        echo "Backup cleanup complete"

        # Set up synthetic.conf for /mnt firmlink (requires reboot to take effect)
        if ! grep -q "^mnt" /etc/synthetic.conf 2>/dev/null; then
          echo "Setting up /mnt firmlink in synthetic.conf..."
          echo "mnt	System/Volumes/Data/mnt" | sudo tee -a /etc/synthetic.conf > /dev/null
          echo "Note: Reboot required for /mnt firmlink to take effect"
        fi

        # Create mount point in Data volume
        if [ ! -d /System/Volumes/Data/mnt ]; then
          sudo mkdir -p /System/Volumes/Data/mnt
        fi

        # Create auto_nfs file for automounter
        sudo tee /etc/auto_nfs > /dev/null <<'EOF'
    # NFS mounts from various hosts
    NFS-storage         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc alienware.home.urandom.io:/export/storage
    NFS-data            -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc alienware.home.urandom.io:/export/data
    NFS-storage-fast    -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc hal9000.home.urandom.io:/export/storage-fast
    hal9000-AI          -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp hal9000.home.urandom.io:/storage-fast/AI
    NFS-n100-01         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-01.home.urandom.io:/export
    NFS-n100-02         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-02.home.urandom.io:/export
    NFS-n100-03         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-03.home.urandom.io:/export
    NFS-n100-04         -fstype=nfs,noowners,nolockd,noresvport,hard,bg,intr,rw,tcp,nfc n100-04.home.urandom.io:/export
    EOF

        # Update auto_master to include our NFS mounts in /mnt
        if grep -q "/Volumes.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Remove the problematic /Volumes entry
          sudo sed -i "" '/\/Volumes.*auto_nfs/d' /etc/auto_master 2>/dev/null || true
        fi

        if ! grep -q "/System/Volumes/Data/mnt.*auto_nfs" /etc/auto_master 2>/dev/null; then
          # Remove old /mnt entry if present
          sudo sed -i "" '/^\/mnt.*auto_nfs/d' /etc/auto_master 2>/dev/null || true
          # Backup existing auto_master
          sudo cp /etc/auto_master "/etc/auto_master.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
          # Add our mount configuration to /System/Volumes/Data/mnt
          echo "/System/Volumes/Data/mnt		/etc/auto_nfs" | sudo tee -a /etc/auto_master > /dev/null
        fi

        # Restart automount to pick up changes
        sudo automount -cv 2>/dev/null || true
  '';

  # Post-activation for authorized_keys and secrets
  system.activationScripts.postActivation.text = lib.mkAfter ''
        echo "Copying authorized_keys to standard location for compatibility..."

        # Ensure .ssh directory exists with correct permissions
        mkdir -p /Users/jamesbrink/.ssh
        chown jamesbrink:staff /Users/jamesbrink/.ssh
        chmod 700 /Users/jamesbrink/.ssh

        # Copy nix-managed authorized_keys to standard location
        if [ -f /etc/ssh/nix_authorized_keys.d/jamesbrink ]; then
          cp /etc/ssh/nix_authorized_keys.d/jamesbrink /Users/jamesbrink/.ssh/authorized_keys
          chown jamesbrink:staff /Users/jamesbrink/.ssh/authorized_keys
          chmod 600 /Users/jamesbrink/.ssh/authorized_keys
          echo "Authorized keys copied to ~/.ssh/authorized_keys"
        fi

        echo "Setting up AWS configuration for jamesbrink..."
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.aws

          # Copy the decrypted AWS config files
          cp -f ${config.age.secrets."aws-config".path} /Users/jamesbrink/.aws/config
          cp -f ${config.age.secrets."aws-credentials".path} /Users/jamesbrink/.aws/credentials

          # Fix permissions
          chmod 600 /Users/jamesbrink/.aws/config /Users/jamesbrink/.aws/credentials
        "
        echo "AWS configuration deployed to /Users/jamesbrink/.aws/"

        echo "Setting up GitHub token environment for jamesbrink..."
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.config/environment.d

          if [[ -f ${config.age.secrets."github-token".path} ]]; then
            echo 'export GITHUB_TOKEN=\"\$(cat ${
              config.age.secrets."github-token".path
            })\"' > /Users/jamesbrink/.config/environment.d/github-token.sh
          else
            echo '# GitHub token not yet available from agenix' > /Users/jamesbrink/.config/environment.d/github-token.sh
          fi

          chmod 600 /Users/jamesbrink/.config/environment.d/github-token.sh
        "
        echo "GitHub token environment deployed"

        echo "Setting up PyPI token environment for jamesbrink..."
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.config/environment.d

          if [[ -f ${config.age.secrets."pypi-key".path} ]]; then
            TOKEN=\"\$(cat ${config.age.secrets."pypi-key".path})\"
            cat > /Users/jamesbrink/.config/environment.d/pypi-token.sh <<EOF
    export PYPI_TOKEN=\"\$TOKEN\"
    export PYPI_API_TOKEN=\"\$TOKEN\"
    export UV_PUBLISH_TOKEN=\"\$TOKEN\"
    export UV_PUBLISH_USERNAME=\"jamesbrink\"
    export POETRY_PYPI_TOKEN_PYPI=\"\$TOKEN\"
    export TWINE_USERNAME=\"__token__\"
    export TWINE_PASSWORD=\"\$TOKEN\"
    EOF
          else
            echo '# PyPI token not yet available from agenix' > /Users/jamesbrink/.config/environment.d/pypi-token.sh
          fi

          chmod 600 /Users/jamesbrink/.config/environment.d/pypi-token.sh
        "
        echo "PyPI token environment deployed"

        echo "Installing hal9000 kubeconfig for jamesbrink..."
        sudo -u jamesbrink ${pkgs.bash}/bin/bash -c '
          set -euo pipefail
          HAL_URL="https://hal9000.home.urandom.io:6443"
          mkdir -p /Users/jamesbrink/.kube
          '"${pkgs.gnused}/bin/sed"' \
            -e "s|https://127.0.0.1:6443|$HAL_URL|g" \
            -e "s|https://localhost:6443|$HAL_URL|g" \
            '"${config.age.secrets."hal9000-kubeconfig".path}"' > /Users/jamesbrink/.kube/config
          chmod 600 /Users/jamesbrink/.kube/config
        '
        echo "hal9000 kubeconfig deployed to /Users/jamesbrink/.kube/config"
  '';
}
