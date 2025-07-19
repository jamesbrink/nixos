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

      home.file."${homeDir}/.ssh/config.d/00-local-hosts" = {
        source = ./ssh/config.d/00-local-hosts;
      };

      home.sessionVariables =
        {
          CLAUDE_BASH_COMMAND_TIMEOUT = "150000";
          CLAUDE_BASH_COMMAND_MAX_TIMEOUT = "600000";
        }
        // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
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

            # Restic aliases
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

            # Restic environment configuration
            if [ -f "$HOME/.config/restic/s3-env" ]; then
              set -a
              source "$HOME/.config/restic/s3-env"
              set +a
            fi
            export RESTIC_REPOSITORY="s3:s3.us-west-2.amazonaws.com/urandom-io-backups/$(hostname -s)"
            if [ -f "$HOME/.config/restic/password" ]; then
              export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
            fi

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

            # Source GitHub Token if available (with race condition protection)
            if [[ -f ~/.config/environment.d/github-token.sh ]]; then
              source ~/.config/environment.d/github-token.sh 2>/dev/null || true
            fi

            # Source Infracost API key if available (with race condition protection)
            if [[ -f ~/.config/environment.d/infracost-api-key.sh ]]; then
              source ~/.config/environment.d/infracost-api-key.sh 2>/dev/null || true
            fi

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
                local hosts=(alienware hal9000 n100-01 n100-02 n100-03 n100-04 halcyon sevastopol darkstarmk6mod1)
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
            # Include Nix-managed local hosts configuration first
            "${config.home.homeDirectory}/.ssh/config.d/00-local-hosts"
            # Then include user's external config for manual additions
            "${homeDir}/.ssh/config_external"
          ];
        };

        neovim = {
          enable = true;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;

          # Language server support
          withNodeJs = true;
          withPython3 = true;
          withRuby = false;

          # Core plugins for functionality
          plugins = with pkgs.vimPlugins; [
            # UI and themes
            vim-airline
            vim-airline-themes
            vim-startify

            # Core functionality
            vim-sensible
            vim-surround
            vim-commentary
            vim-repeat
            vim-fugitive
            vim-gitgutter
            vim-tmux-navigator

            # File navigation
            telescope-nvim
            plenary-nvim

            # Language support
            ansible-vim
            nvim-sops
            vim-terraform
            vim-markdown
            vim-nix

            # LSP and completion
            nvim-lspconfig
            nvim-cmp
            cmp-nvim-lsp
            cmp-buffer
            cmp-path
            cmp-cmdline
            luasnip
            cmp_luasnip

            # Treesitter for better syntax highlighting
            (nvim-treesitter.withPlugins (p: [
              p.python
              p.bash
              p.lua
              p.vim
              p.vimdoc
              p.markdown
              p.terraform
              p.hcl
              p.json
              p.yaml
              p.toml
              p.nix
            ]))

            # Quality of life
            vim-lastplace
            vim-smoothie
            indent-blankline-nvim
            which-key-nvim
          ];

          extraConfig = ''
            "" General
            set number
            set history=1000
            set nocompatible
            set modelines=0
            set encoding=utf-8
            set scrolloff=3
            set showmode
            set showcmd
            set hidden
            set wildmenu
            set wildmode=list:longest
            set cursorline
            set ttyfast
            set nowrap
            set ruler
            set backspace=indent,eol,start
            set laststatus=2
            " set clipboard=autoselect

            " Dir stuff
            set nobackup
            set nowritebackup
            set noswapfile
            set backupdir=~/.config/vim/backups
            set directory=~/.config/vim/swap

            " Relative line numbers for easy movement
            set relativenumber
            set rnu

            "" Whitespace rules
            set tabstop=8
            set shiftwidth=2
            set softtabstop=2
            set expandtab

            "" Searching
            set incsearch
            set gdefault

            "" Statusbar
            set nocompatible " Disable vi-compatibility
            set laststatus=2 " Always show the statusline
            let g:airline_theme='bubblegum'
            let g:airline_powerline_fonts = 1

            "" Local keys and such
            let mapleader=","
            let maplocalleader=" "

            "" Change cursor on mode
            :autocmd InsertEnter * set cul
            :autocmd InsertLeave * set nocul

            "" File-type highlighting and configuration
            syntax on
            filetype on
            filetype plugin on
            filetype indent on

            "" Paste from clipboard
            nnoremap <Leader>, "+gP

            "" Copy from clipboard
            xnoremap <Leader>. "+y

            "" Move cursor by display lines when wrapping
            nnoremap j gj
            nnoremap k gk

            "" Map leader-q to quit out of window
            nnoremap <leader>q :q<cr>

            "" Move around split
            nnoremap <C-h> <C-w>h
            nnoremap <C-j> <C-w>j
            nnoremap <C-k> <C-w>k
            nnoremap <C-l> <C-w>l

            "" Easier to yank entire line
            nnoremap Y y$

            "" Move buffers
            nnoremap <tab> :bnext<cr>
            nnoremap <S-tab> :bprev<cr>

            "" Like a boss, sudo AFTER opening the file to write
            cmap w!! w !sudo tee % >/dev/null

            let g:startify_lists = [
              \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
              \ { 'type': 'sessions',  'header': ['   Sessions']       },
              \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
              \ ]

            let g:startify_bookmarks = [
              \ '~/.local/share/src',
              \ ]

            let g:airline_theme='bubblegum'
            let g:airline_powerline_fonts = 1

            "" Telescope bindings (updating from old config)
            nnoremap <leader>ff <cmd>Telescope find_files<cr>
            nnoremap <leader>fg <cmd>Telescope live_grep<cr>
            nnoremap <leader>fb <cmd>Telescope buffers<cr>
            nnoremap <leader>fh <cmd>Telescope help_tags<cr>
          '';

          extraLuaConfig = ''
            -- LSP Configuration
            local lspconfig = require('lspconfig')
            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            -- Python LSP
            lspconfig.pyright.setup{
              capabilities = capabilities,
            }

            -- Bash LSP
            lspconfig.bashls.setup{
              capabilities = capabilities,
            }

            -- Terraform LSP
            lspconfig.terraformls.setup{
              capabilities = capabilities,
            }

            -- Markdown LSP
            lspconfig.marksman.setup{
              capabilities = capabilities,
            }

            -- Nix LSP
            lspconfig.nil_ls.setup{
              capabilities = capabilities,
              settings = {
                ['nil'] = {
                  formatting = {
                    command = { "nixfmt" },
                  },
                },
              },
            }

            -- Completion setup
            local cmp = require('cmp')
            local luasnip = require('luasnip')

            cmp.setup({
              snippet = {
                expand = function(args)
                  luasnip.lsp_expand(args.body)
                end,
              },
              mapping = cmp.mapping.preset.insert({
                ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                ['<C-f>'] = cmp.mapping.scroll_docs(4),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
                ['<Tab>'] = cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_next_item()
                  elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                  else
                    fallback()
                  end
                end, { 'i', 's' }),
                ['<S-Tab>'] = cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_prev_item()
                  elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                  else
                    fallback()
                  end
                end, { 'i', 's' }),
              }),
              sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
              }, {
                { name = 'buffer' },
                { name = 'path' },
              })
            })

            -- Treesitter configuration
            require('nvim-treesitter.configs').setup {
              highlight = {
                enable = true,
              },
              indent = {
                enable = true,
              },
            }

            -- Indent blankline
            require("ibl").setup()

            -- Which-key
            require("which-key").setup()
          '';
        };
      };

      # Heroku CLI configuration with authentication
      home.activation.setupHeroku = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        HEROKU_KEY_PATH="/run/agenix/heroku-key"
        if [ -f "$HEROKU_KEY_PATH" ]; then
          cat > ${homeDir}/.netrc <<EOF
        machine api.heroku.com
          login brink.james@gmail.com
          password $(cat "$HEROKU_KEY_PATH")
        machine git.heroku.com
          login brink.james@gmail.com
          password $(cat "$HEROKU_KEY_PATH")
        EOF
          chmod 600 ${homeDir}/.netrc
        fi
      '';
    };
}
