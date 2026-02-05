# Shared Nix configuration for all hosts (caches + system limits)
{ lib, ... }:

{
  # Increase file descriptor limits to prevent "Too many open files" during builds
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "65536";
    }
  ];

  # Also increase limits for nix-daemon specifically
  systemd.services.nix-daemon.serviceConfig.LimitNOFILE = 65536;

  nix.settings = {
    substituters = lib.mkAfter [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://comfyui.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://cache.flox.dev"
    ];
    trusted-substituters = lib.mkAfter [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://comfyui.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://cache.flox.dev"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };
}
