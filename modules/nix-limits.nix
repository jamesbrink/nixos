# Increase file descriptor limits for Nix builds (NixOS only)
# Prevents "Too many open files" errors during large builds
{ ... }:

{
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
}
