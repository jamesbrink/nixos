# Root user configuration with home-manager
{
  config,
  pkgs,
  lib,
  secretsPath ? null,
  ...
}:

let
  # Use the secretsPath from function arguments if available, otherwise try from module args
  effectiveSecretsPath =
    if secretsPath != null then
      secretsPath
    else if (config._module.args.secretsPath or null) != null then
      config._module.args.secretsPath
    else
      "./secrets"; # Fallback for remote deployments
in
{
  # Root user account configuration
  users.users.root = {
    hashedPasswordFile = lib.mkIf pkgs.stdenv.isLinux config.age.secrets."root-hashed-password".path;
    openssh.authorizedKeys.keys = lib.mkIf pkgs.stdenv.isLinux [
      # SSH public keys for root
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/oRSpEnuE4edzkc7VHhIhe9Y4tTTjl/9489JjC19zY jamesbrink@darkstarmk6mod1"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmcoMbMstPPKsGH0oQLv8N6WgDSt8jvqcXpPfNkzAMq jamesbrink@bender.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArPfE2X8THR73peLxwMfd4uCXH8A3moM/T1l+HvgDva" # ViteTunnel
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARkb1kXdTi41j9j9JLPtY1+HxskjrSCkqyB5Dx0vcqj root@Alienware15R4"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkFHSY+3XcW54uu4POE743wYdh4+eGIR68O8121X29m root@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRNDnoVLI8Zy9YjOkHQuX6m9f9EzW8W2lYxnoGDjXtM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSf4Qft9nUD2gRDeJVkogYKY7PQvhlnD+kjFKgro3r"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKlaSFMo6Wcm5oZu3ABjPY4Q+INQBlVwxVktjfz66oI root@n100-04"
    ];
  };

  # Age secret for root password (Linux only)
  age.secrets."root-hashed-password" = lib.mkIf pkgs.stdenv.isLinux {
    file = "${effectiveSecretsPath}/global/root/hashed-password.age";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  # Home-manager configuration for root
  home-manager.users.root =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.stateVersion = "25.05";

      # Root's home directory
      home.homeDirectory = if pkgs.stdenv.isDarwin then "/var/root" else "/root";

      # Import the unified shell configuration
      imports = [
        ../modules/home-manager/shell
      ];

      # Root-specific overrides
      programs.git.settings.user = {
        name = "root";
        email = "root@localhost";
      };

      # Simplified shell aliases for root
      programs.zsh.shellAliases = {
        # Root-specific overrides
        ll = lib.mkForce "ls -la";
        la = lib.mkForce "ls -la";
        lt = lib.mkForce "ls -ltr";
        cleanup = lib.mkForce "nix-collect-garbage -d";
      };

      # Root prompt customization
      programs.starship.settings = {
        # Use the same two-line minimal format
        format = lib.mkForce "$username$hostname$directory$git_branch$git_status$nix_shell$aws\n$character";

        username = {
          show_always = true;
          style_user = lib.mkForce "red bold";
          style_root = lib.mkForce "red bold";
          format = lib.mkForce "[$user]($style) ";
        };
      };

      # Disable some features for root
      programs.direnv.enable = lib.mkForce false;
    };
}
