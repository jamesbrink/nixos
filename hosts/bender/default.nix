# Host configuration for bender - Mac Mini M4
# Slim, headless configuration for SSH-focused usage
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../profiles/darwin-slim # Minimal darwin profile
    ../../modules/darwin/maintenance-tools.nix
    ../../modules/services/bonsai2-darwin.nix
    ../../modules/ssh-keys.nix
    ../../users/regular/jamesbrink-darwin-slim.nix
  ];

  # Networking
  networking = {
    hostName = "bender";
    computerName = "Bender";
    localHostName = "bender";
  };

  # Time zone
  time.timeZone = "America/Phoenix";

  # Point mold CLI at hal9000's inference server
  environment.variables.MOLD_HOST = "http://hal9000.home.urandom.io:7680";

  # Links ~/.omp/agent to the omp-config checkout.
  home-manager.users.jamesbrink = {
    imports = [ ../../modules/home-manager/omp-config.nix ];
    local.ompConfig.host = "bender";
  };

  # Bonsai 2 runs behind llama-swap so its unified-memory allocation is released
  # after idle periods. The base M4's 16 GB tier uses one 32K Q8-KV Metal slot.
  services.bonsai2 = {
    enable = true;
    host = "0.0.0.0";
  };

  # OpenClaw, Hermes and their skill dependencies were removed on 2026-11-09
  # (archive: hal9000 /mnt/storage20tb/Backups/bender-openclaw-hermes-2026-11-09).
  # Peekaboo stays for macOS UI automation over SSH.
  homebrew.taps = [
    "openclaw/tap" # Peekaboo's current home; steipete/tap stopped at 4.3.0
  ];

  homebrew.brews = [
    "openclaw/tap/peekaboo" # macOS UI automation
  ];

  # Peekaboo's Bridge daemon, started by launchd inside the GUI session.
  # macOS grants Screen Recording to the RESPONSIBLE process: a daemon that an SSH
  # session auto-spawns is attributed to sshd, which has no such grant, so captures
  # driven over SSH fail. Started here it is attributed to the peekaboo binary,
  # which holds the grants, and SSH/MCP clients reuse it over its bridge socket.
  launchd.user.agents.peekaboo-daemon = {
    serviceConfig = {
      ProgramArguments = [
        "/opt/homebrew/bin/peekaboo"
        "daemon"
        "run"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      LimitLoadToSessionType = "Aqua";
      StandardOutPath = "/tmp/peekaboo-daemon.log";
      StandardErrorPath = "/tmp/peekaboo-daemon.log";
    };
  };

  homebrew.casks = [
    "bitwarden" # Password manager
    "ghostty" # Terminal emulator
    "tailscale" # VPN/mesh networking
    "telegram" # Messaging
  ];

  # InvokeAI service
  # TODO: disabled — mediapipe fails to build on aarch64-darwin (x86_64 wheel + missing jax/jaxlib)
  # services.invokeai = {
  #   enable = true;
  #   user = "jamesbrink";
  # };

  # AI Toolkit training service
  # TODO: disabled — torchaudio 2.11.0 build broken in nixpkgs-unstable (empty TORCHAUDIO_TEST_ALLOW_SKIP_IF_NO_QUANTIZATION env var)
  # services.ai-toolkit = {
  #   enable = true;
  #   user = "jamesbrink";
  #   secrets = {
  #     claudeOauthTokenFile = config.age.secrets."claude-secondary".path;
  #     hfTokenFile = config.age.secrets."huggingface-token".path;
  #   };
  # };
}
