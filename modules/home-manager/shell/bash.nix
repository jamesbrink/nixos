# Bash configuration for all users
{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.bash = {
    enable = true;

    shellAliases = {
      # Basic aliases
      ll = "ls -l";
      la = "ls -la";
      lt = "ls -ltr";

      # Modern replacements
      # cat = "bat";
      # find = "fd";
      # ps = "procs";

      # Git aliases
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log";
      gd = "git diff";

      # Pay respects (thefuck replacement)
      fuck = "pay-respects";
      pr = "pay-respects";
    };

    historyControl = [ ]; # Empty array means no history control (keep all duplicates)
    historyFile = "${config.home.homeDirectory}/.bash_history";
    historyFileSize = -1; # Unlimited history file size
    historySize = -1; # Unlimited history size in memory

    initExtra = ''
      # Bash history options for infinite history
      export HISTSIZE=-1                # Unlimited history in memory
      export HISTFILESIZE=-1            # Unlimited history file size
      export HISTTIMEFORMAT="%F %T "    # Add timestamps to history
      shopt -s histappend               # Append to history, don't overwrite
      shopt -s cmdhist                  # Save multi-line commands as single entry

      # Save history after each command
      export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

      # Fix terminal issues
      if [[ "$TERM" == "alacritty" ]]; then
        export TERM=xterm-256color
      fi

      # Handle Ghostty terminal  
      if [[ "$TERM" == "xterm-ghostty" ]]; then
        if ! infocmp xterm-ghostty >/dev/null 2>&1; then
          export TERM=xterm-256color
        fi
      fi

      # Ensure terminfo is available
      export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/usr/share/terminfo:${pkgs.ncurses}/share/terminfo"

      # Fix backspace key
      stty erase '^?'

      # Source Nix daemon if available
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # AWS Configuration
      export AWS_PAGER=""

      # Source environment files
      for env_file in github-token infracost-api-key pypi-token deadmansnitch-api-key; do
        if [[ -f ~/.config/environment.d/$env_file.sh ]]; then
          source ~/.config/environment.d/$env_file.sh 2>/dev/null || true
        fi
      done
    '';
  };
}
