# Zsh configuration for all users
{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.home.homeDirectory;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "kubectl"
        "terraform"
        "aws"
        "npm"
        "python"
        "sudo"
        "systemd"
        "tmux"
        "z"
      ];
      theme = "robbyrussell";
    };

    shellAliases = {
      # eza aliases (modern ls replacement with ls-compatible shortcuts)
      ll = "eza -l";
      la = "eza -la";
      lt = "eza -l --sort=modified";
      ltr = "eza -l --sort=modified --reverse";
      lart = "eza -la --sort=modified --reverse"; # Your favorite!
      l = "eza -l";
      tree = "eza --tree";

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

      # System management
      cleanup = if pkgs.stdenv.isDarwin then "nix-collect-garbage -d" else "sudo nix-collect-garbage -d";

      # Restic aliases - these now use the wrapper function from restic-shell-init.nix
      backup =
        if pkgs.stdenv.isDarwin then
          "restic-backup backup"
        else
          "sudo systemctl start restic-backups-s3-backup.service";
      snapshots = "restic snapshots";
      restic-check = "restic check";
      restic-restore = "restic restore";
      restic-mount = "restic mount";
      restic-ls = "restic ls";
      restic-cat = "restic cat";
      restic-diff = "restic diff";
      restic-stats = "restic stats";
      restic-prune = "restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-yearly 2";

      # Utility aliases
      search = "rg -p --glob '!node_modules/*' $@";
      diff = "difft";

      # Pay respects (thefuck replacement)
      fuck = "pay-respects";
      pr = "pay-respects";
    };

    history = {
      size = 2147483647; # Maximum integer value for unlimited history
      save = 2147483647; # Maximum integer value for unlimited saves
      path = "${homeDir}/.zsh_history";
      extended = true; # Save timestamps
      ignoreDups = false; # Keep duplicate entries
      share = true; # Share history between sessions
    };

    initContent = ''
      # Add ~/.local/bin for pipx and ~/.claude/local for Claude CLI
      export PATH="$HOME/.local/bin:$HOME/.claude/local:$PATH"

      # Disable Nix hyperlinks in error messages (prevents underlined text)
      export NIX_DONT_HYPERLINK=1

      # Disable exit confirmation (no "you have running jobs" or "you have stopped jobs" warnings)
      setopt NO_CHECK_JOBS
      setopt NO_HUP

      # ZSH Options
      # Note: SHARE_HISTORY is enabled via programs.zsh.history.share = true
      # This automatically handles appending and sharing, so we don't set APPEND_HISTORY
      setopt INC_APPEND_HISTORY      # Write to history file immediately
      setopt NO_HIST_IGNORE_ALL_DUPS # Keep all duplicate entries
      setopt HIST_REDUCE_BLANKS      # Remove superfluous blanks
      setopt NO_HIST_SAVE_NO_DUPS    # Save duplicate entries
      setopt NO_HIST_FIND_NO_DUPS    # Display duplicates when searching
      setopt EXTENDED_HISTORY        # Save timestamp with commands
      # SHARE_HISTORY is already set by home-manager from programs.zsh.history.share = true

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

      # Nix shell helper
      shell() {
        nix-shell '<nixpkgs>' -A "$1"
      }

      # ls wrapper function to translate GNU ls flags to eza
      # Remove any existing ls alias first
      unalias ls 2>/dev/null || true

      ls() {
        local args=()
        local sort_by_time=false
        local reverse=false

        # Parse arguments, translating GNU ls flags into eza equivalents
        for arg in "$@"; do
          if [[ "$arg" == --* ]]; then
            args+=("$arg")
            continue
          fi

          if [[ "$arg" == "-"* ]]; then
            local stripped="''${arg#-}"
            local keep_flags=""
            for ((i = 0; i < ''${#stripped}; i++)); do
              case "''${stripped:i:1}" in
                t) sort_by_time=true ;; # handled separately to map to eza sort
                r) reverse=true ;;
                *) keep_flags+="''${stripped:i:1}" ;;
              esac
            done
            [[ -n "$keep_flags" ]] && args+=("-$keep_flags")
          else
            args+=("$arg")
          fi
        done

        if $sort_by_time; then
          args+=(--sort=modified)
          # eza sorts oldest->newest by default; align -t with ls (newest first)
          if ! $reverse; then
            args+=(--reverse)
          fi
        elif $reverse; then
          args+=(--reverse)
        fi

        ${pkgs.eza}/bin/eza "''${args[@]}"
      }

      # Source Nix daemon if available
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # Restic environment configuration is handled by wrapper functions
      # See modules/restic-shell-init.nix for credential isolation implementation

      # Source environment files (with race condition protection)
      for env_file in github-token infracost-api-key pypi-token deadmansnitch-api-key; do
        if [[ -f ~/.config/environment.d/$env_file.sh ]]; then
          source ~/.config/environment.d/$env_file.sh 2>/dev/null || true
        fi
      done

      # AWS Configuration
      export AWS_PAGER=""

      aws-profile() {
        unset AWS_PROFILE AWS_EB_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        local profile_name="$1"
        local token_code="$2"
        export AWS_PROFILE="$profile_name"
        export SOURCE_AWS_PROFILE="$AWS_PROFILE"
        export AWS_EB_PROFILE="$profile_name"
        export SOURCE_AWS_EB_PROFILE="$AWS_EB_PROFILE"
        caller_identity="$(aws sts get-caller-identity)"
        account_number="$(echo $caller_identity | jq -r '.Account')"
        arn="$(echo $caller_identity | jq -r '.Arn')"
        mfa="$(echo $arn | sed 's|\:user/|\:mfa/|g')"
        export SOURCE_AWS_PROFILE SOURCE_AWS_EB_PROFILE AWS_PROFILE AWS_EB_PROFILE
        if [ -n "$token_code" ]; then
          AWS_CREDENTIALS="$(aws sts get-session-token --serial-number "$mfa" --token-code "$token_code")"
          export AWS_ACCESS_KEY_ID="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')"
          export SOURCE_AWS_ACCESS_KEY="$AWS_ACCESS_KEY_ID"
          export AWS_SECRET_ACCESS_KEY="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')"
          export SOURCE_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
          export AWS_SESSION_TOKEN="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.SessionToken')"
          export SOURCE_AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
        fi
        echo "Using AWS Account: $account_number ($profile_name) - ARN: $arn"
      }

      aws-role() {
        local role_arn="$1"
        eval $(aws sts assume-role --role-arn "$role_arn" --role-session-name "$USER@$HOST" | jq -r '.Credentials | @sh "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)", @sh "export AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)", @sh "export AWS_SESSION_TOKEN=\(.SessionToken)"')
        aws sts get-caller-identity
      }

      aws-no-role() {
        export AWS_PROFILE="$SOURCE_AWS_PROFILE"
        export AWS_EB_PROFILE="$SOURCE_AWS_EB_PROFILE"
        export AWS_ACCESS_KEY_ID="$SOURCE_AWS_ACCESS_KEY_ID"
        export AWS_SECRET_ACCESS_KEY="$SOURCE_AWS_SECRET_ACCESS_KEY"
        export AWS_SESSION_TOKEN="$SOURCE_AWS_SESSION_TOKEN"
      }

      # Ghostty SSH helper
      ghostty-ssh-setup() {
        local host="$1"
        if [[ -z "$host" ]]; then
          echo "Usage: ghostty-ssh-setup <hostname>"
          echo "       ghostty-ssh-setup all  # Setup on all known hosts"
          return 1
        fi
        
        setup_single_host() {
          local target="$1"
          echo -n "Setting up Ghostty terminfo on $target... "
          
          if ! command -v infocmp >/dev/null 2>&1; then
            echo "SKIP (infocmp not found)"
            return 1
          fi
          
          if ! infocmp xterm-ghostty >/dev/null 2>&1; then
            echo "SKIP (xterm-ghostty not found locally)"
            return 1
          fi
          
          if ssh -o ConnectTimeout=5 "$target" "infocmp xterm-ghostty" >/dev/null 2>&1; then
            echo "already installed"
            return 0
          fi
          
          if infocmp -x xterm-ghostty | ssh -o ConnectTimeout=5 "$target" -- tic -x - 2>/dev/null; then
            echo "✓"
            return 0
          else
            echo "✗ (failed)"
            return 1
          fi
        }
        
        if [[ "$host" == "all" ]]; then
          echo "Setting up Ghostty terminfo on all configured hosts..."
          local hosts=(alienware hal9000 n100-01 n100-02 n100-03 n100-04 halcyon sevastopol)
          for h in ''${hosts[@]}; do
            setup_single_host "$h"
          done
        else
          setup_single_host "$host"
        fi
      }
    '';
  };
}
