# Unified shell experience for all users including root
# Provides consistent shell utilities and configuration across all hosts
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Neovim configuration that can be used on both platforms
  neovimConfig = pkgs.neovim.override {
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
in
{
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
    oh-my-zsh

    # Development tools
    git
    delta
    lazygit

    # System tools
    htop
    btop
    ncdu
    duf

    # Neovim with our custom configuration
    neovimConfig
  ];

  # Set up vim/vi aliases
  environment.shellAliases = {
    vim = "${neovimConfig}/bin/nvim";
    vi = "${neovimConfig}/bin/nvim";
  };

  # Set default editor (with lower priority to allow overrides)
  environment.variables = {
    EDITOR = lib.mkOverride 900 "${neovimConfig}/bin/nvim";
    VISUAL = lib.mkOverride 900 "${neovimConfig}/bin/nvim";
  };

  # Starship configuration
  environment.etc."starship.toml".text = ''
    # Use the default format but ensure single line
    add_newline = false

    [username]
    show_always = true
    style_user = "green bold"
    style_root = "red bold"
    format = "[$user]($style) "

    [hostname]
    ssh_only = false
    style = "dimmed green"
    format = "in 🌐 [$hostname]($style) "

    [directory]
    style = "cyan bold"
    format = "in [$path]($style) "
    truncation_length = 3
    truncate_to_repo = false

    [git_branch]
    style = "purple bold"
    format = "on [$symbol$branch]($style) "

    [git_status]
    style = "red bold"
    format = "[$all_status$ahead_behind]($style) "

    [aws]
    style = "yellow bold"
    format = "on ☁️  [$profile( \\($region\\))]($style) "
    symbol = ""

    [character]
    success_symbol = "[❯](bold green)"
    error_symbol = "[❯](bold red)"

    # Disable modules that might add extra lines
    [line_break]
    disabled = false

    [cmd_duration]
    disabled = true

    [jobs]
    disabled = true
  '';
}
