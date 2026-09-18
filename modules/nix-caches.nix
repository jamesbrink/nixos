# Shared binary cache configuration for all hosts
{ lib, ... }:

{
  nix.settings = {
    substituters = lib.mkAfter [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://comfyui.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
    ];
    trusted-substituters = lib.mkAfter [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://comfyui.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://cache.flox.dev"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };
}
