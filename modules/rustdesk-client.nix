{
  config,
  pkgs,
  lib,
  secretsPath,
  ...
}:
let
  cfg = config.services.rustdesk-client;
  # Use unstablePkgs from the flake overlay which has allowUnfree = true
  rustdeskPkg = pkgs.unstablePkgs.rustdesk;
in
{
  options.services.rustdesk-client = {
    enable = lib.mkEnableOption "RustDesk remote desktop client";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable headless mode with dummy X driver for systems without physical displays.
        When true, configures a virtual display using the X dummy driver.
        When false, uses the system's real graphics drivers.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # RustDesk client configuration with permanent password
    # Based on RustDesk's official headless Linux support documentation:
    # https://github.com/rustdesk/rustdesk/wiki/Headless-Linux-Support

    # Decrypt the RustDesk password from secrets
    # Mode 0444 (world-readable) allows user services to access it
    age.secrets.rustdesk-password = {
      file = "${secretsPath}/global/rustdesk-password.age";
      mode = "0444";
      owner = "root";
    };

    # Install RustDesk from unstable (latest version)
    environment.systemPackages = [
      rustdeskPkg
    ]
    ++ lib.optionals cfg.headless [
      pkgs.xorg.xf86videodummy
    ];

    # Headless-only configuration: Force X server to use dummy driver
    services.xserver.videoDrivers = lib.mkIf cfg.headless (lib.mkOverride 40 [ "dummy" ]);

    # Configure dummy X driver for headless virtual display
    # This creates a virtual display that behaves like a real GPU
    services.xserver.deviceSection = lib.mkIf cfg.headless ''
      VideoRam 256000
    '';

    services.xserver.monitorSection = lib.mkIf cfg.headless ''
      HorizSync 28.0-80.0
      VertRefresh 48.0-75.0
      # 1920x1080 @ 60.00 Hz (GTF) hsync: 67.08 kHz; pclk: 172.80 MHz
      Modeline "1920x1080_60.00" 172.80 1920 2040 2248 2576 1080 1081 1084 1118 -HSync +Vsync
    '';

    services.xserver.screenSection = lib.mkIf cfg.headless ''
      DefaultDepth 24
      SubSection "Display"
        Depth 24
        Modes "1920x1080_60.00"
      EndSubSection
    '';

    # Setup service to configure RustDesk with headless mode and password
    # Based on official documentation at https://github.com/rustdesk/rustdesk/wiki/Headless-Linux-Support
    # This service runs at boot and enables headless mode + sets the password
    systemd.services.rustdesk-setup = {
      description = "Configure RustDesk for headless operation";
      wantedBy = [ "multi-user.target" ];
      after = [
        "local-fs.target"
        "display-manager.service"
      ];
      wants = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Environment = [
          "DISPLAY=:0"
          "HOME=/root"
        ]
        ++ lib.optionals cfg.headless [
          "XAUTHORITY=/run/lightdm/root/:0"
        ];
      };
      script = ''
        # Read password from agenix secret
        RUSTDESK_PASSWORD=$(${pkgs.coreutils}/bin/cat ${config.age.secrets.rustdesk-password.path})
        RUSTDESK_BIN="${rustdeskPkg}/bin/rustdesk"

        # Wait for display to be ready
        for i in {1..30}; do
          if ${pkgs.xorg.xdpyinfo}/bin/xdpyinfo -display :0 >/dev/null 2>&1; then
            echo "Display :0 is ready"
            break
          fi
          echo "Waiting for display :0 to be ready... ($i/30)"
          sleep 2
        done

        # Enable headless mode (required for headless operation)
        ${lib.optionalString cfg.headless ''
          echo "Enabling RustDesk headless mode..."
          $RUSTDESK_BIN --option allow-linux-headless Y
        ''}

        # Set the permanent password
        echo "Setting RustDesk password..."
        $RUSTDESK_BIN --password "$RUSTDESK_PASSWORD"

        # Get and display the RustDesk ID for connection
        echo "RustDesk ID:"
        $RUSTDESK_BIN --get-id

        echo "RustDesk configuration complete"
      '';
    };

    # RustDesk system service (runs as root for emergency console access)
    # Runs the main RustDesk process after configuration
    systemd.services.rustdesk = {
      description = "RustDesk Remote Desktop";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "rustdesk-setup.service"
        "display-manager.service"
      ];
      wants = [
        "rustdesk-setup.service"
        "display-manager.service"
      ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        WorkingDirectory = "/root";
        Environment = [
          "HOME=/root"
          "DISPLAY=:0"
        ]
        ++ lib.optionals cfg.headless [
          "XAUTHORITY=/run/lightdm/root/:0"
        ];
        # Run RustDesk in service mode without GUI window
        ExecStart = "${rustdeskPkg}/bin/rustdesk --server";
        Restart = "always";
        RestartSec = 10;
        # Give it time to start properly
        TimeoutStartSec = 30;
      };
    };

    # Ensure X11 backend is used (not Wayland) for RustDesk compatibility
    environment.sessionVariables = {
      RUSTDESK_DISPLAY_BACKEND = "x11";
    };

    # Create rustdesk data directory for root user (emergency console access)
    systemd.tmpfiles.rules = [
      "d /root/.local/share/rustdesk 0755 root root - -"
    ];
  };
}
