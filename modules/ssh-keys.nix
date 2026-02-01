# SSH keys configuration for all hosts
{
  config,
  lib,
  pkgs ? null,
  ...
}:

let
  # All authorized SSH keys from secrets.nix
  authorizedKeys = [
    # SSH public keys for user jamesbrink
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQdtaj2iZIndBqpu9vlSxRFgvLxNEV2afiqqdznsrEh jamesbrink@MacBook-Pro"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkGQPzTxSwBg/2h9H1xAPkUACIP7Mh+lT4d+PibPW47 jamesbrink@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1EnHDJYUbWvJt8KEksgROsuC48uyB4kaCTKZjc10Sz jamesbrink@Derp"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmcoMbMstPPKsGH0oQLv8N6WgDSt8jvqcXpPfNkzAMq jamesbrink@bender.local"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArPfE2X8THR73peLxwMfd4uCXH8A3moM/T1l+HvgDva" # ViteTunnel
    # System keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARkb1kXdTi41j9j9JLPtY1+HxskjrSCkqyB5Dx0vcqj root@Alienware15R4"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkFHSY+3XcW54uu4POE743wYdh4+eGIR68O8121X29m root@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRNDnoVLI8Zy9YjOkHQuX6m9f9EzW8W2lYxnoGDjXtM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSf4Qft9nUD2gRDeJVkogYKY7PQvhlnD+kjFKgro3r"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKlaSFMo6Wcm5oZu3ABjPY4Q+INQBlVwxVktjfz66oI root@n100-04"
    # Nix remote builder keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBvJiS9lYBJ/LHMElCEj5y8fRsq1h1Xg1einEVz6z29U root@halcyon-nix-builder"
  ];
in
{
  # Configure SSH keys for root user on all systems
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
}
