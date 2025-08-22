{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable VSCode Server with proper configuration
  services.vscode-server = {
    enable = true;
  };

  # Add environment variables to help with extension installation
  environment.systemPackages = with pkgs; [
    nodejs_20 # Required for many extensions
    python3 # Required for Python extensions
  ];

  # Create systemd service to fix permissions and clean up broken installs
  systemd.user.services.vscode-server-fix = {
    description = "Fix VSCode Server extension verification issues";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "vscode-server-fix" ''
        # Clean up any corrupted extension databases
        for dir in $HOME/.vscode-server*; do
          if [ -d "$dir" ]; then
            # Remove extension signature cache if it exists
            rm -rf "$dir/data/CachedExtensionVSIXs" 2>/dev/null || true
            rm -rf "$dir/data/logs/exthost" 2>/dev/null || true
            
            # Fix permissions on extension directories
            find "$dir/extensions" -type d -exec chmod 755 {} \; 2>/dev/null || true
            find "$dir/extensions" -type f -exec chmod 644 {} \; 2>/dev/null || true
            
            # Clear corrupted extension database
            if [ -f "$dir/data/User/globalStorage/state.vscdb" ]; then
              rm -f "$dir/data/User/globalStorage/state.vscdb-shm" 2>/dev/null || true
              rm -f "$dir/data/User/globalStorage/state.vscdb-wal" 2>/dev/null || true
            fi
          fi
        done
      '';
    };
  };

  # Add firewall rules for VSCode Server
  networking.firewall = {
    allowedTCPPortRanges = [
      {
        from = 9000;
        to = 9999;
      } # VSCode Server default port range
    ];
  };

  # Ensure proper file watching limits for large projects
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };
}
