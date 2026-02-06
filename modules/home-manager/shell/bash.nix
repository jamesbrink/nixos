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

    # Disable home-manager's bash completion - it generates code using the -v operator
    # which requires bash 4.2+, but macOS /bin/bash is 3.2 and hangs on syntax errors
    enableCompletion = false;

    # Override default shellOptions to be compatible with macOS's ancient bash 3.2
    # Default includes globstar/checkjobs which require bash 4.0+
    # Bash 4+ features are added in initExtra with version guards
    shellOptions = [
      "histappend"
      "checkwinsize"
      "extglob"
      # globstar - bash 4.0+ only, added in initExtra
      # checkjobs - bash 4.0+ only, added in initExtra
    ];

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
    # Use large values instead of -1; HISTSIZE=-1 only works in bash 4.3+ and hangs bash 3.2
    historyFileSize = 10000000;
    historySize = 10000000;

    initExtra = ''
      # Enable bash 4.0+ features if available (macOS ships bash 3.2)
      if [[ ''${BASH_VERSINFO[0]} -ge 4 ]]; then
        shopt -s globstar     # ** recursive glob
        shopt -s checkjobs    # Warn before exit with running jobs

        # Bash completion - use ''${var+x} pattern which works in bash 3.2+
        # (the -v operator requires bash 4.2+ and causes parse errors in older bash)
        if [[ -z "''${BASH_COMPLETION_VERSINFO+x}" ]]; then
          source "${pkgs.bash-completion}/etc/profile.d/bash_completion.sh"
        fi
      fi

      # Bash history options - use large values for bash 3.2 compat (HISTSIZE=-1 requires bash 4.3+)
      if [[ ''${BASH_VERSINFO[0]} -ge 4 && ''${BASH_VERSINFO[1]} -ge 3 ]] || [[ ''${BASH_VERSINFO[0]} -ge 5 ]]; then
        export HISTSIZE=-1              # Unlimited history in memory (bash 4.3+)
        export HISTFILESIZE=-1          # Unlimited history file size (bash 4.3+)
      else
        export HISTSIZE=10000000        # Large history for bash 3.2
        export HISTFILESIZE=10000000
      fi
      export HISTTIMEFORMAT="%F %T "    # Add timestamps to history
      shopt -s histappend               # Append to history, don't overwrite
      shopt -s cmdhist                  # Save multi-line commands as single entry

      # Save history after each command (bash 4+ only - history manipulation can hang bash 3.2)
      if [[ ''${BASH_VERSINFO[0]} -ge 4 ]]; then
        PROMPT_COMMAND="history -a; history -c; history -r''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
      fi

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
      for env_file in github-token infracost-api-key pypi-token deadmansnitch-api-key claude-primary-token claude-secondary-token openrouter-key; do
        if [[ -f ~/.config/environment.d/$env_file.sh ]]; then
          source ~/.config/environment.d/$env_file.sh 2>/dev/null || true
        fi
      done

      # Claude Code account switching
      claude-profile() {
        local profile_name="$1"
        case "$profile_name" in
          primary|1)
            unset ANTHROPIC_API_KEY
            export CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN_PRIMARY"
            export CLAUDE_CURRENT_PROFILE="primary"
            echo "Switched to Claude primary account (OAuth)"
            ;;
          secondary|2)
            unset ANTHROPIC_API_KEY
            export CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN_SECONDARY"
            export CLAUDE_CURRENT_PROFILE="secondary"
            echo "Switched to Claude secondary account (OAuth)"
            ;;
          api)
            unset CLAUDE_CODE_OAUTH_TOKEN
            if [[ -f ~/.config/environment.d/anthropic-key.sh ]]; then
              source ~/.config/environment.d/anthropic-key.sh
              export CLAUDE_CURRENT_PROFILE="api"
              echo "Switched to Anthropic API key"
            else
              echo "Error: anthropic-key.sh not found"
              return 1
            fi
            ;;
          none|unset|off|0)
            unset CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CURRENT_PROFILE
            echo "All Claude credentials unset"
            ;;
          status|s)
            echo "Profile:  ''${CLAUDE_CURRENT_PROFILE:-none}"
            echo "OAuth:    $([[ -n "''${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] && echo "set (...''${CLAUDE_CODE_OAUTH_TOKEN: -8})" || echo "unset")"
            echo "API key:  $([[ -n "''${ANTHROPIC_API_KEY:-}" ]] && echo "set (...''${ANTHROPIC_API_KEY: -8})" || echo "unset")"
            ;;
          ""|*)
            echo "Usage: claude-profile {primary|secondary|api|none|status|1|2|s|0}"
            echo ""
            echo "Profile:  ''${CLAUDE_CURRENT_PROFILE:-none}"
            echo "OAuth:    $([[ -n "''${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] && echo "set (...''${CLAUDE_CODE_OAUTH_TOKEN: -8})" || echo "unset")"
            echo "API key:  $([[ -n "''${ANTHROPIC_API_KEY:-}" ]] && echo "set (...''${ANTHROPIC_API_KEY: -8})" || echo "unset")"
            [[ -n "$profile_name" ]] && return 1
            ;;
        esac
      }

      # Initialize default Claude profile (halcyon uses primary, all others use secondary)
      # Unset ANTHROPIC_API_KEY to avoid conflicts with OAuth tokens
      unset ANTHROPIC_API_KEY
      if [[ "$(hostname -s)" == "halcyon" ]] && [[ -n "$CLAUDE_CODE_OAUTH_TOKEN_PRIMARY" ]]; then
        export CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN_PRIMARY"
        export CLAUDE_CURRENT_PROFILE="primary"
      elif [[ -n "$CLAUDE_CODE_OAUTH_TOKEN_SECONDARY" ]]; then
        export CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN_SECONDARY"
        export CLAUDE_CURRENT_PROFILE="secondary"
      fi
    '';
  };
}
