{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

with lib;

{
  config = mkMerge [
    # Age secret configuration (common for both platforms)
    {
      age.secrets.claude-desktop-config = {
        file = "${secretsPath}/global/claude-desktop-config.age";
        mode = "644";
      };
    }
    # Darwin activation
    (mkIf pkgs.stdenv.isDarwin {
      system.activationScripts.postActivation.text = mkAfter ''
        echo "Setting up Claude desktop configuration for Darwin..."
        # For Darwin - deploy to Library/Application Support/Claude
        CLAUDE_DIR="/Users/jamesbrink/Library/Application Support/Claude"

        # Run as the user with sudo
        sudo -u jamesbrink bash -c "
          if [ ! -d '$CLAUDE_DIR' ]; then
            mkdir -p '$CLAUDE_DIR'
          fi
          
          # Copy the decrypted config with correct filename (underscores, not hyphens)
          cp -f ${config.age.secrets.claude-desktop-config.path} '$CLAUDE_DIR/claude_desktop_config.json'
          chmod 644 '$CLAUDE_DIR/claude_desktop_config.json'
        "
        echo "Claude desktop configuration deployed to $CLAUDE_DIR/claude_desktop_config.json"
      '';
    })

    # Linux activation
    (mkIf pkgs.stdenv.isLinux {
      system.activationScripts.claudeDesktopConfig = {
        text = ''
          echo "Setting up Claude desktop configuration for Linux..."
          # For Linux - deploy to user's .config/Claude
          CLAUDE_DIR="/home/jamesbrink/.config/Claude"

          if [ ! -d "$CLAUDE_DIR" ]; then
            mkdir -p "$CLAUDE_DIR"
            chown jamesbrink:users "$CLAUDE_DIR"
          fi

          # Copy the decrypted config with correct filename (underscores, not hyphens)
          cp -f ${config.age.secrets.claude-desktop-config.path} "$CLAUDE_DIR/claude_desktop_config.json"
          chown jamesbrink:users "$CLAUDE_DIR/claude_desktop_config.json"
          chmod 644 "$CLAUDE_DIR/claude_desktop_config.json"
          echo "Claude desktop configuration deployed to $CLAUDE_DIR/claude_desktop_config.json"
        '';
        deps = [ "agenix" ];
      };
    })
  ];
}
