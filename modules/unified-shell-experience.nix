# Unified shell experience for all users including root
# Provides consistent tmux, zsh, and neovim configuration across all hosts
{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # Tmux configuration
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 10000;
    keyMode = "vi";
    shortcut = "b";
    terminal = "screen-256color";
    # Note: System-level tmux doesn't support plugins
    # Plugins are handled by home-manager for regular users
    extraConfig = ''
      # Mouse support
      set -g mouse on
      
      # Status bar
      set -g status-position bottom
      set -g status-style 'bg=colour234 fg=colour137'
      
      # Vi-style copy mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
      
      # Clipboard integration
      ${if isDarwin then ''
        bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
        bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
      '' else ''
        bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
        bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
      ''}
      
      # Window navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      
      # Resizing panes
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5
      
      # Split panes using | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      
      # Reload config
      bind r source-file /etc/tmux.conf \; display-message "Config reloaded!"
    '';
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    
    # Shell aliases that match user config
    shellAliases = {
      ll = "ls -la";
      la = "ls -la";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      
      # Git aliases
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log";
      gd = "git diff";
      
      # Modern replacements
      ls = "${pkgs.eza}/bin/eza";
      cat = "${pkgs.bat}/bin/bat";
      find = "${pkgs.fd}/bin/fd";
      ps = "${pkgs.procs}/bin/procs";
      
      # The original 'thefuck' replacement
      fuck = "${pkgs.pay-respects}/bin/pay-respects";
      pr = "${pkgs.pay-respects}/bin/pay-respects";
    };
    
    # Oh-my-zsh configuration
    ohMyZsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "docker"
        "kubectl"
        "terraform"
        "aws"
        "colored-man-pages"
        "command-not-found"
        "sudo"
      ];
      # Prevent permission issues with completion updates
      cacheDir = "/tmp/oh-my-zsh-cache-\${USER}";
    };
    
    # Interactive shell init (for all users including root)
    interactiveShellInit = ''
      # Starship prompt
      if command -v starship &> /dev/null; then
        eval "$(${pkgs.starship}/bin/starship init zsh)"
      fi
      
      # Set default editor
      export EDITOR="${pkgs.neovim}/bin/nvim"
      export VISUAL="${pkgs.neovim}/bin/nvim"
      
      # Better history
      export HISTSIZE=100000
      export SAVEHIST=100000
      export HISTFILE="$HOME/.zsh_history"
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_FIND_NO_DUPS
      setopt HIST_SAVE_NO_DUPS
      setopt SHARE_HISTORY
      
      # Directory navigation
      setopt AUTO_CD
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
      
      # Completion settings
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      
      # FZF integration if available
      if command -v fzf &> /dev/null; then
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        source ${pkgs.fzf}/share/fzf/completion.zsh
      fi
    '';
  };

  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    
    configure = {
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          # Core functionality
          vim-sensible
          vim-surround
          vim-commentary
          vim-repeat
          
          # File navigation
          nerdtree
          fzf-vim
          
          # Git integration
          vim-fugitive
          vim-gitgutter
          
          # Syntax and language support
          nvim-treesitter
          nvim-treesitter-parsers.c
          nvim-treesitter-parsers.lua
          nvim-treesitter-parsers.nix
          nvim-treesitter-parsers.python
          nvim-treesitter-parsers.javascript
          nvim-treesitter-parsers.typescript
          nvim-treesitter-parsers.go
          nvim-treesitter-parsers.rust
          
          # LSP support
          nvim-lspconfig
          
          # Status line
          lualine-nvim
          
          # Color scheme
          gruvbox-material
          
          # Tmux integration
          vim-tmux-navigator
          
          # Better terminal
          toggleterm-nvim
        ];
      };
      
      customRC = ''
        " Basic settings
        syntax on
        filetype plugin indent on
        set number
        set relativenumber
        set hidden
        set encoding=utf-8
        set title
        set showmatch
        set ignorecase
        set smartcase
        set hlsearch
        set incsearch
        set expandtab
        set tabstop=2
        set shiftwidth=2
        set softtabstop=2
        set autoindent
        set smartindent
        set ruler
        set wrap
        set breakindent
        set mouse=a
        set clipboard=unnamedplus
        set updatetime=300
        set signcolumn=yes
        set termguicolors
        
        " Set leader key
        let mapleader = " "
        
        " Color scheme
        set background=dark
        colorscheme gruvbox-material
        
        " Key mappings
        nnoremap <leader>w :w<CR>
        nnoremap <leader>q :q<CR>
        nnoremap <leader>e :NERDTreeToggle<CR>
        nnoremap <leader>f :Files<CR>
        nnoremap <leader>b :Buffers<CR>
        nnoremap <leader>g :Rg<CR>
        
        " Clear search highlight
        nnoremap <leader>h :nohlsearch<CR>
        
        " Better window navigation
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l
        
        " Maintain visual selection after indenting
        vnoremap < <gv
        vnoremap > >gv
        
        " Move lines up and down
        nnoremap <A-j> :m .+1<CR>==
        nnoremap <A-k> :m .-2<CR>==
        vnoremap <A-j> :m '>+1<CR>gv=gv
        vnoremap <A-k> :m '<-2<CR>gv=gv
        
        " Terminal settings
        if has('nvim')
          tnoremap <Esc> <C-\><C-n>
          autocmd TermOpen * startinsert
        endif
        
        " Auto-save on focus lost
        autocmd FocusLost * silent! wa
        
        " Highlight yanked text
        autocmd TextYankPost * silent! lua vim.highlight.on_yank()
        
        " Lua configurations
        lua << EOF
        -- Lualine setup
        require('lualine').setup {
          options = {
            theme = 'gruvbox-material'
          }
        }
        
        -- Treesitter setup
        require('nvim-treesitter.configs').setup {
          highlight = {
            enable = true,
          },
          indent = {
            enable = true,
          },
        }
        EOF
      '';
    };
  };
  
  # Starship prompt configuration - clean single-line style
  programs.starship = {
    enable = true;
    settings = {
      # Use the default format but ensure single line
      add_newline = false;
      
      username = {
        show_always = true;
        style_user = "green bold";  # Default starship color
        style_root = "red bold";
        format = "[$user]($style) ";
      };
      
      hostname = {
        ssh_only = false;
        style = "dimmed green";  # Default starship color
        format = "in 🌐 [$hostname]($style) ";
      };
      
      directory = {
        style = "cyan bold";  # Default starship color
        format = "in [$path]($style) ";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      
      git_branch = {
        style = "purple bold";  # Default starship color
        format = "on [$symbol$branch]($style) ";
      };
      
      git_status = {
        style = "red bold";
        format = "[$all_status$ahead_behind]($style) ";
      };
      
      aws = {
        style = "yellow bold";  # Default starship color for AWS
        format = "on ☁️  [$profile( \\($region\\))]($style) ";
        symbol = "";
      };
      
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
      
      # Disable modules that might add extra lines
      line_break.disabled = false;
      cmd_duration.disabled = true;
      jobs.disabled = true;
    };
  };

  # Ensure tools are available system-wide
  environment.systemPackages = with pkgs; [
    # Shell utilities
    starship
    fzf
    ripgrep
    fd
    bat
    eza
    procs
    pay-respects
    
    # Development tools
    git
    delta
    lazygit
    
    # System tools
    htop
    btop
    ncdu
    duf
    
    # Clipboard support
  ] ++ lib.optionals (!isDarwin) [
    xclip
  ];
  
  # Set default shell for users
  users.defaultUserShell = pkgs.zsh;
  
  # For Darwin, configure path
  environment.pathsToLink = lib.optionals isDarwin [
    "/share/zsh"
  ];
}