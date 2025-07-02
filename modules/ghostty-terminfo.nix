# Ghostty terminfo configuration module
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.ghostty-terminfo;

  # Create a terminfo package for Ghostty
  ghosttyTerminfo =
    pkgs.runCommand "ghostty-terminfo"
      {
        nativeBuildInputs = [ pkgs.ncurses ];
      }
      ''
        mkdir -p $out/share/terminfo

        # Create xterm-ghostty terminfo entry
        cat > ghostty.terminfo << 'EOF'
        # Ghostty terminal emulator
        # Based on xterm-256color with Ghostty-specific capabilities
        xterm-ghostty|Ghostty terminal emulator,
          use=xterm-256color,
          # Additional capabilities can be added here as needed
          # For now, we inherit everything from xterm-256color
        EOF

        tic -x -o $out/share/terminfo ghostty.terminfo
      '';
in
{
  options.programs.ghostty-terminfo = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable Ghostty terminfo support";
    };
  };

  config = mkIf cfg.enable {
    # Add ghostty terminfo to system packages
    environment.systemPackages = [ ghosttyTerminfo ];

    # Set up terminfo paths
    environment.sessionVariables = {
      TERMINFO_DIRS = mkDefault "${ghosttyTerminfo}/share/terminfo:$\{TERMINFO_DIRS:-/usr/share/terminfo}";
    };

    # For sudo environments, preserve TERMINFO
    security.sudo.extraConfig = ''
      # Preserve terminfo environment for Ghostty
      Defaults env_keep += "TERMINFO TERMINFO_DIRS"
    '';

    # Create a system activation script to ensure terminfo is available
    system.activationScripts.ghosttyTerminfo = stringAfter [ "users" ] ''
      # Ensure Ghostty terminfo is available system-wide
      if [ -d "${ghosttyTerminfo}/share/terminfo" ]; then
        # Link to system terminfo if writable
        if [ -w /usr/share/terminfo ] 2>/dev/null; then
          ln -sf ${ghosttyTerminfo}/share/terminfo/x/xterm-ghostty /usr/share/terminfo/x/ 2>/dev/null || true
        fi
      fi
    '';
  };
}
