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

  # Single activation script that handles both Darwin and Linux
  system.activationScripts.claudeDesktopConfig.text = 
    if pkgs.stdenv.isDarwin then ''
      echo "Setting up Claude desktop configuration for Darwin..."
      # For Darwin - deploy to Library/Application Support/Claude
      CLAUDE_DIR="/Users/jamesbrink/Library/Application Support/Claude"
      
      # Run as the user with sudo
      sudo -u jamesbrink bash -c "
        if [ ! -d '$CLAUDE_DIR' ]; then
          mkdir -p '$CLAUDE_DIR'
        fi
        
        # Link the decrypted config
        ln -sf ${config.age.secrets.claude-desktop-config.path} '$CLAUDE_DIR/claude_desktop_config.json'
      "
      echo "Claude desktop configuration linked to $CLAUDE_DIR/claude_desktop_config.json"
    ''
    else if pkgs.stdenv.isLinux then ''
      echo "Setting up Claude desktop configuration for Linux..."
      # For Linux - deploy to user's .config/Claude
      CLAUDE_DIR="/home/jamesbrink/.config/Claude"
      
      if [ ! -d "$CLAUDE_DIR" ]; then
        mkdir -p "$CLAUDE_DIR"
        chown jamesbrink:users "$CLAUDE_DIR"
      fi
      
      # Link the decrypted config
      ln -sf ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
      echo "Claude desktop configuration linked to $CLAUDE_DIR/claude_desktop_config.json"
    ''
    else "";
}