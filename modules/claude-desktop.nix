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

  # For Darwin systems
  system.activationScripts.postUserActivation.text = lib.mkIf pkgs.stdenv.isDarwin ''
    echo "Setting up Claude desktop configuration..."
    # For Darwin - deploy to Library/Application Support/Claude
    CLAUDE_DIR="/Users/jamesbrink/Library/Application Support/Claude"
    
    if [ ! -d "$CLAUDE_DIR" ]; then
      mkdir -p "$CLAUDE_DIR"
      chown jamesbrink:staff "$CLAUDE_DIR"
    fi
    
    # Link the decrypted config
    ln -sf ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
    echo "Claude desktop configuration linked to $CLAUDE_DIR/claude_desktop_config.json"
  '';

  # For Linux systems, use activation script
  system.activationScripts.claudeDesktopConfig = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      echo "Setting up Claude desktop configuration..."
      # For Linux - deploy to user's .config/Claude
      CLAUDE_DIR="/home/jamesbrink/.config/Claude"
      
      if [ ! -d "$CLAUDE_DIR" ]; then
        mkdir -p "$CLAUDE_DIR"
        chown jamesbrink:users "$CLAUDE_DIR"
      fi
      
      # Link the decrypted config
      ln -sf ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
      echo "Claude desktop configuration linked to $CLAUDE_DIR/claude_desktop_config.json"
    '';
  };
}