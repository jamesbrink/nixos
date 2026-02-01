# Darwin-specific user configuration
{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

let
  unstable = pkgs.unstablePkgs;
in
{
  imports = [
    ./jamesbrink-shared.nix
    ../../modules/claude-desktop.nix
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

  # User packages
  home-manager.users.jamesbrink =
    { pkgs, ... }:
    {
      _module.args.inputs = inputs;

      imports = [
        ../../modules/home-manager/darwin/unified-themes.nix
        ../../modules/home-manager/darwin/hammerspoon.nix
        ../../modules/home-manager/darwin/cursor-extensions.nix
      ];

      # Install missing theme extensions to VSCode and Cursor
      programs.editor.extraThemeExtensions.enable = true;

      home.packages = with pkgs; [
        # Common packages for darwin
        atuin
        ffmpeg-full
        gurk-rs
        imagemagick
        nushell
        pay-respects
        xonsh
        yt-dlp

        # Darwin-specific CLI tools
        # TODO: Update aider-chat to use latest unstable once texlive build issue is fixed on Darwin
        # The issue is with texlive-bin-big-2025 failing due to malformed version number on macOS
        # Using aider-chat 0.82.2 from older nixpkgs commit to avoid pypandoc/texlive dependency
        (
          let
            olderNixpkgs =
              import
                (builtins.fetchTarball {
                  url = "https://github.com/NixOS/nixpkgs/archive/b6aef6c3553f849e1e6c08f1bcd3061df2b69fc4.tar.gz";
                  sha256 = "1n7pii2bcx3k4yfjma47fdf4pm8k005a9ls0kscykx5j0rdllja3";
                })
                {
                  system = pkgs.stdenv.hostPlatform.system;
                  config.allowUnfree = true;
                };
          in
          olderNixpkgs.aider-chat
        )
        unstable.code2prompt
        unstable.llm
      ];
    };

  # Age configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/Users/jamesbrink/.ssh/id_ed25519"
  ];

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

  age.secrets."deadmansnitch-key" = {
    file = "${secretsPath}/jamesbrink/deadmansnitch-key.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."heroku-key" = {
    file = "${secretsPath}/jamesbrink/heroku-key.age";
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

  age.secrets."infracost-api-key" = {
    file = "${secretsPath}/global/infracost/api-key.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  # Darwin-specific activation script for AWS config and GitHub token
  system.activationScripts.postActivation.text = lib.mkAfter ''
        echo "Setting up AWS configuration for jamesbrink..."
        # Run as the user with sudo
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
        # Run as the user with sudo
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.config/environment.d
          
          # Create GitHub token environment file (check if agenix path exists first)
          if [[ -f ${config.age.secrets."github-token".path} ]]; then
            echo 'export GITHUB_TOKEN=\"\$(cat ${
              config.age.secrets."github-token".path
            })\"' > /Users/jamesbrink/.config/environment.d/github-token.sh
          else
            echo '# GitHub token not yet available from agenix' > /Users/jamesbrink/.config/environment.d/github-token.sh
          fi
          
          # Fix permissions
          chmod 600 /Users/jamesbrink/.config/environment.d/github-token.sh
        "
        echo "GitHub token environment deployed to /Users/jamesbrink/.config/environment.d/"

        echo "Setting up Infracost API key environment for jamesbrink..."
        # Run as the user with sudo
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.config/environment.d
          
          # Create Infracost API key environment file (check if agenix path exists first)
          if [[ -f ${config.age.secrets."infracost-api-key".path} ]]; then
            echo 'export INFRACOST_API_KEY=\"\$(cat ${
              config.age.secrets."infracost-api-key".path
            })\"' > /Users/jamesbrink/.config/environment.d/infracost-api-key.sh
          else
            echo '# Infracost API key not yet available from agenix' > /Users/jamesbrink/.config/environment.d/infracost-api-key.sh
          fi
          
          # Fix permissions
          chmod 600 /Users/jamesbrink/.config/environment.d/infracost-api-key.sh
        "
        echo "Infracost API key environment deployed to /Users/jamesbrink/.config/environment.d/"

        echo "Setting up PyPI token environment for jamesbrink..."
        # Run as the user with sudo
        sudo -u jamesbrink bash -c "
          mkdir -p /Users/jamesbrink/.config/environment.d
          
          # Create PyPI token environment file (check if agenix path exists first)
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
          
          # Fix permissions
          chmod 600 /Users/jamesbrink/.config/environment.d/pypi-token.sh
        "
        echo "PyPI token environment deployed to /Users/jamesbrink/.config/environment.d/"

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

        echo "Setting up Dead Man's Snitch API key environment for jamesbrink..."
        # Run as the user with sudo
        sudo -u jamesbrink bash -c '
          mkdir -p /Users/jamesbrink/.config/environment.d
          
          # Create Dead Man'"'"'s Snitch API key environment file (check if agenix path exists first)
          if [[ -f ${config.age.secrets."deadmansnitch-key".path} ]]; then
            echo "export DEADMANSNITCH_API_KEY=\"\$(cat ${
              config.age.secrets."deadmansnitch-key".path
            })\"" > /Users/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
          else
            echo "# Dead Man'"'"'s Snitch API key not yet available from agenix" > /Users/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
          fi
          
          # Fix permissions
          chmod 600 /Users/jamesbrink/.config/environment.d/deadmansnitch-api-key.sh
        '
        echo "Dead Man's Snitch API key environment deployed to /Users/jamesbrink/.config/environment.d/"
  '';
}
