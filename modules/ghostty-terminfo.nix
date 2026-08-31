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

  # Ghostty's own terminfo description, straight from the upstream package.
  #
  # Do NOT substitute a hand-rolled `xterm-ghostty|use=xterm-256color` alias
  # here: that silently drops the capabilities Ghostty actually advertises,
  # most importantly the mouse ones --
  #   kmous=\E[<   XM=\E[?1006;1000...   xm=\E[<%i%p3%d;...
  # A terminfo entry that claims legacy X10 mouse (kmous=\E[M) while the
  # terminal really speaks SGR (1006) makes ncurses programs enable and
  # disable the wrong mouse modes, which is one way mouse reporting gets left
  # switched on and starts injecting literal "65;88;41M" text at the prompt.
  ghosttyTerminfo = pkgs.ghostty.terminfo;
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
