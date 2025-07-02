# Shared user configuration for both Linux and Darwin
{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = if pkgs.stdenv.isDarwin then "/Users/jamesbrink" else "/home/jamesbrink";
in
{
  # Common home-manager configuration
  home-manager.users.jamesbrink =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.stateVersion = "25.05";

      home.file."${homeDir}/.ssh/config_external" = {
        source = ./ssh/config_external;
      };

      home.sessionVariables = lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
        SSH_AUTH_SOCK = "/run/user/$(id -u)/ssh-agent";
      };

      programs = {
        starship = {
          enable = true;
        };

        direnv = {
          enable = true;
          nix-direnv = {
            enable = !pkgs.stdenv.isDarwin; # Disabled on Darwin due to Determinate Nix conflict
          };
          enableZshIntegration = true;
        };

        git = {
          enable = true;
          userName = "James Brink";
          userEmail = "brink.james@gmail.com";
          extraConfig = {
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;
          };
        };

        tmux = {
          enable = true;
          baseIndex = 1;
          escapeTime = 0;
          keyMode = "vi";
          shortcut = "a";
          terminal = "screen-256color";
          plugins = with pkgs.tmuxPlugins; [
            vim-tmux-navigator
            sensible
            yank
          ];
          extraConfig = ''
            # Mouse support
            set -g mouse on

            # Clipboard integration
            bind-key -T copy-mode-vi v send-keys -X begin-selection
            ${
              if pkgs.stdenv.isDarwin then
                ''
                  bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
                ''
              else
                ''
                  bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
                ''
            }
          '';
        };

        alacritty = {
          enable = true;
          settings = {
            env = {
              TERM = "xterm-256color"; # Use xterm-256color for better compatibility
            };
            window =
              {
                padding = {
                  x = 24;
                  y = 24;
                };
                opacity = 1.0;
              }
              // lib.optionalAttrs pkgs.stdenv.isDarwin {
                option_as_alt = "Both";
              };
            font = {
              normal = {
                family = "MesloLGS Nerd Font";
                style = "Regular";
              };
              size = if pkgs.stdenv.isDarwin then 14 else 10;
            };
            colors = {
              # Rosé Pine theme
              primary = {
                background = "0x191724";
                foreground = "0xe0def4";
              };
              cursor = {
                text = "0x191724";
                cursor = "0xe0def4";
              };
              normal = {
                black = "0x26233a";
                red = "0xeb6f92";
                green = "0x31748f";
                yellow = "0xf6c177";
                blue = "0x9ccfd8";
                magenta = "0xc4a7e7";
                cyan = "0xebbcba";
                white = "0xe0def4";
              };
              bright = {
                black = "0x6e6a86";
                red = "0xeb6f92";
                green = "0x31748f";
                yellow = "0xf6c177";
                blue = "0x9ccfd8";
                magenta = "0xc4a7e7";
                cyan = "0xebbcba";
                white = "0xe0def4";
              };
            };
            cursor = {
              style = "Block";
            };
            selection = {
              save_to_clipboard = true;
            };
            mouse = {
              hide_when_typing = false;
            };
          };
        };

        zsh = {
          enable = true;
          enableCompletion = true;
          syntaxHighlighting.enable = true;

          oh-my-zsh = {
            enable = true;
            plugins = [
              "git"
            ];
            theme = "robbyrussell";
          };

          shellAliases = {
            ll = "ls -l";
            update =
              if pkgs.stdenv.isDarwin then
                "darwin-rebuild switch --flake ~/Projects/jamesbrink/nixos#halcyon"
              else
                "sudo nixos-rebuild switch --flake /etc/nixos/#default";
            cleanup = if pkgs.stdenv.isDarwin then "nix-collect-garbage -d" else "sudo nix-collect-garbage -d";
          };

          history = {
            size = 1000000000; # Nearly unlimited (1 billion entries)
            save = 1000000000; # Save nearly unlimited entries
            path = "${homeDir}/.zsh_history";
            extended = true; # Save timestamps
            ignoreDups = false; # Keep duplicate entries
            share = true; # Share history between sessions
          };
          initContent = ''
            # Fix terminal issues
            if [[ "$TERM" == "alacritty" ]]; then
              export TERM=xterm-256color
            fi

            # Handle Ghostty terminal
            if [[ "$TERM" == "xterm-ghostty" ]]; then
              # Check if terminfo entry exists
              if ! infocmp xterm-ghostty >/dev/null 2>&1; then
                # Fallback to xterm-256color if xterm-ghostty is not available
                export TERM=xterm-256color
              fi
            fi

            # Ensure terminfo is available
            export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/usr/share/terminfo:${pkgs.ncurses}/share/terminfo"

            # Fix backspace key
            stty erase '^?'

            # ZSH History Configuration - Never overwrite, always append
            setopt APPEND_HISTORY          # Append to history file, don't overwrite
            setopt INC_APPEND_HISTORY      # Write to history file immediately, not when shell exits
            setopt NO_HIST_IGNORE_ALL_DUPS # Keep all duplicate entries
            setopt HIST_REDUCE_BLANKS      # Remove superfluous blanks from history items
            setopt NO_HIST_SAVE_NO_DUPS    # Save duplicate entries in the history file
            setopt NO_HIST_FIND_NO_DUPS    # Display duplicates when searching history
            setopt EXTENDED_HISTORY        # Save timestamp along with commands
            setopt SHARE_HISTORY           # Share history between all sessions

            if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
              . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
            fi

            # Ripgrep alias
            alias search='rg -p --glob "!node_modules/*" $@'

            # Pay respects (thefuck replacement)
            alias fuck='pay-respects'
            alias pr='pay-respects'

            # nix shortcuts
            shell() {
                nix-shell '<nixpkgs>' -A "$1"
            }

            # Use difftastic, syntax-aware diffing
            alias diff=difft

            # Always color ls and group directories
            alias ls='ls --color=auto'

            # GitHub Token
            export GITHUB_TOKEN="<TBD>"

            ##############
            # AWS Settings
            ##############
            export AWS_PAGER=""
            aws-profile() {
                unset AWS_PROFILE AWS_EB_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
                local profile_name="$1"
                local token_code="$2"
                export AWS_PROFILE="$profile_name"
                export SOURCE_AWS_PROFILE="$AWS_PROFILE"
                export AWS_EB_PROFILE="$profile_name"
                export SOURCE_AWS_EB_PROFIL=E"$AWS_EB_PROFILE"
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

            # Alias for claude code
            alias claude="~/.claude/local/claude"

            # Ghostty SSH helper - copy terminfo to remote host
            ghostty-ssh-setup() {
              local host="$1"
              if [[ -z "$host" ]]; then
                echo "Usage: ghostty-ssh-setup <hostname>"
                echo "       ghostty-ssh-setup all  # Setup on all known hosts"
                return 1
              fi
              
              # Function to setup a single host
              setup_single_host() {
                local target="$1"
                echo -n "Setting up Ghostty terminfo on $target... "
                
                # Check if we have ghostty terminfo locally
                if ! command -v infocmp >/dev/null 2>&1; then
                  echo "SKIP (infocmp not found)"
                  return 1
                fi
                
                if ! infocmp xterm-ghostty >/dev/null 2>&1; then
                  echo "SKIP (xterm-ghostty not found locally)"
                  return 1
                fi
                
                # Check if host already has it
                if ssh -o ConnectTimeout=5 "$target" "infocmp xterm-ghostty" >/dev/null 2>&1; then
                  echo "already installed"
                  return 0
                fi
                
                # Copy terminfo to remote host
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
                local hosts=(alienware hal9000 n100-01 n100-02 n100-03 n100-04 sevastopol-linux halcyon sevastopol)
                for h in ''${hosts[@]}; do
                  setup_single_host "$h"
                done
              else
                setup_single_host "$host"
              fi
            }
          '';
        };

        ssh = {
          enable = true;
          controlMaster = "auto";
          includes = [
            "${homeDir}/.ssh/config_external"
          ];
        };
      };
    };
}
