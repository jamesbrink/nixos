{
  config,
  pkgs,
  lib,
  secretsPath,
  ...
}:

{
  # RustDesk client configuration with permanent password
  # This module sets up RustDesk in server mode with a permanent password from agenix

  # Decrypt the RustDesk password from secrets
  # Mode 0444 (world-readable) allows user services to access it
  age.secrets.rustdesk-password = {
    file = "${secretsPath}/global/rustdesk-password.age";
    mode = "0444";
    owner = "root";
  };

  # Install RustDesk
  environment.systemPackages = [ pkgs.rustdesk ];

  # Setup service to configure RustDesk with permanent password
  # RustDesk will encrypt the plaintext password on first startup
  # This service runs at boot and creates the config file for all users
  systemd.services.rustdesk-password-setup = {
    description = "Set RustDesk permanent password for all users";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
            # Read password from agenix secret
            RUSTDESK_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.age.secrets.rustdesk-password.path})

            # Create RustDesk config for each user in /home
            for user_home in /home/*; do
              if [ -d "$user_home" ]; then
                username=$(basename "$user_home")
                config_dir="$user_home/.config/rustdesk"
                config_file="$config_dir/RustDesk.toml"

                # Create config directory
                mkdir -p "$config_dir"

                # Only create config if it doesn't exist or password is not set
                if [ ! -f "$config_file" ] || ! grep -q "^password = " "$config_file"; then
                  # Write plaintext password - RustDesk will encrypt it on startup
                  cat > "$config_file" <<EOF
      [options]
      password = "$RUSTDESK_PASSWORD"
      direct-server = true
      relay-server = ""
      EOF
                  # Set proper ownership and permissions
                  chown "$username:users" "$config_file"
                  chmod 600 "$config_file"
                  echo "RustDesk password configured for $username"
                fi
              fi
            done
    '';
  };

  # RustDesk system service for headless startup
  # Runs as system service for each user, starts at boot without requiring graphical session
  systemd.services.rustdesk = {
    description = "RustDesk Remote Desktop Server (Headless)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "rustdesk-password-setup.service"
    ];
    wants = [ "rustdesk-password-setup.service" ];
    serviceConfig = {
      Type = "simple";
      # Run as jamesbrink user
      User = "jamesbrink";
      Group = "users";
      # Set home directory for config file access
      WorkingDirectory = "/home/jamesbrink";
      Environment = [
        "HOME=/home/jamesbrink"
        "RUSTDESK_DISPLAY_BACKEND=x11"
      ];
      ExecStart = "${pkgs.rustdesk}/bin/rustdesk --server";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Ensure X11 backend is used (not Wayland) for RustDesk compatibility
  environment.sessionVariables = {
    RUSTDESK_DISPLAY_BACKEND = "x11";
  };

  # Create rustdesk data directory for jamesbrink user
  systemd.tmpfiles.rules = [
    "d /home/jamesbrink/.local/share/rustdesk 0755 jamesbrink users - -"
  ];
}
