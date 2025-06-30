{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

{
  # Deploy Claude desktop config for all users
  age.secrets.claude-desktop-config = {
    file = "${secretsPath}/secrets/global/claude-desktop-config.age";
    mode = "644";
  };

  # Create the Claude config directory and symlink the config
  system.activationScripts.claudeDesktopConfig = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      # For Darwin - deploy to Library/Application Support/Claude
      CLAUDE_DIR="/Users/jamesbrink/Library/Application Support/Claude"
      
      if [ ! -d "$CLAUDE_DIR" ]; then
        mkdir -p "$CLAUDE_DIR"
        chown jamesbrink:staff "$CLAUDE_DIR"
      fi
      
      # Link the decrypted config
      ln -sf ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
    '';
  };

  # For Linux systems, use home-manager to deploy to user config
  home-manager.users.jamesbrink = lib.mkIf pkgs.stdenv.isLinux {
    home.activation.claudeDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Create Claude config directory
      CLAUDE_DIR="$HOME/.config/Claude"
      mkdir -p "$CLAUDE_DIR"
      
      # Link the decrypted config
      ln -sf ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
    '';
  };
}