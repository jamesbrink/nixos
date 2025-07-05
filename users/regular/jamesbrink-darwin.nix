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
      home.packages = with pkgs; [
        # Common packages for darwin
        atuin
        ffmpeg-full
        imagemagick
        nushell
        pay-respects
        tldr
        xonsh
        yt-dlp

        # Darwin-specific CLI tools
        unstable.aider-chat
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
    file = "${secretsPath}/secrets/jamesbrink/aws/config.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."aws-credentials" = {
    file = "${secretsPath}/secrets/jamesbrink/aws/credentials.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  # Darwin-specific activation script for AWS config
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
  '';
}
