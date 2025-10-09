{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.file.".local/state/nvim/shada/.keep".text = "";
  home.file.".local/share/nvim/session/.keep".text = "";
  home.file.".vim/.keep".text = "";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = true;
    withPython3 = true;
    withRuby = false;

    plugins = with pkgs.vimPlugins; [
      # UI and themes
      gruvbox-material
      lualine-nvim
      vim-airline
      vim-airline-themes
      vim-startify
      indent-blankline-nvim
      which-key-nvim

      # Core functionality
      vim-sensible
      vim-surround
      vim-commentary
      vim-repeat
      vim-lastplace
      vim-smoothie

      # File navigation
      telescope-nvim
      plenary-nvim
      nerdtree
      fzf-vim

      # Git integration
      vim-fugitive
      vim-gitgutter

      # Language support and syntax
      (nvim-treesitter.withPlugins (p: [
        p.bash
        p.c
        p.go
        p.hcl
        p.javascript
        p.json
        p.lua
        p.markdown
        p.nix
        p.python
        p.rust
        p.terraform
        p.toml
        p.typescript
        p.vim
        p.vimdoc
        p.yaml
      ]))

      # Language-specific plugins
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

      # Terminal and tmux integration
      toggleterm-nvim
      vim-tmux-navigator
    ];

    extraConfig = ''
      " Basic settings
      syntax on
      filetype plugin indent on
      set number relativenumber
      set hidden
      set encoding=utf-8
      set title
      set showmatch
      set ignorecase smartcase
      set hlsearch incsearch
      set expandtab
      set tabstop=2 shiftwidth=2 softtabstop=2
      set autoindent smartindent
      set ruler
      set wrap breakindent
      set mouse=a
      set clipboard=unnamedplus
      set updatetime=300
      set signcolumn=yes
      set termguicolors
      set cursorline
      set ttyfast
      set scrolloff=3
      set showcmd
      set wildmenu
      set wildmode=list:longest
      set laststatus=2
      set backspace=indent,eol,start
      set modelines=0
      set history=1000

      " Disable backups and swapfiles
      set nobackup
      set nowritebackup
      set noswapfile

      if has('nvim')
        silent! call mkdir(expand('~/.local/state/nvim/shada'), 'p')
        set shada='100,<1000,s100,h
        let &shadafile = expand('~/.local/state/nvim/shada/main.shada')
      else
        silent! call mkdir(expand('~/.vim'), 'p')
        set viminfo='100,<1000,s100,h
        let &viminfofile = expand('~/.vim/viminfo')
      endif

      " Ensure viminfo/shada file exists
      if !has('nvim') && !filereadable(expand('~/.vim/viminfo'))
        silent! execute 'wviminfo'
      endif

      " Disable Startify's viminfo usage completely
      let g:startify_session_delete_buffers = 1
      let g:startify_change_to_vcs_root = 0
      let g:startify_session_sort = 0
      let g:startify_enable_special = 0
      let g:startify_session_before_save = []
      let g:startify_skiplist = [
        \ 'COMMIT_EDITMSG',
        \ '^/tmp',
        \ escape(fnamemodify(resolve($VIMRUNTIME), ':p'), '\') . 'doc',
        \ 'bundle/.*/doc',
        \ ]

      " Set leader keys
      let mapleader = ","
      let maplocalleader = " "

      " Color scheme
      set background=dark
      colorscheme gruvbox-material

      " Airline configuration
      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1

      " Key mappings
      " File operations
      nnoremap <leader>w :w<CR>
      nnoremap <leader>q :q<CR>
      cmap w!! w !sudo tee % >/dev/null

      " File navigation
      nnoremap <leader>e :NERDTreeToggle<CR>
      nnoremap <leader>f :Files<CR>
      nnoremap <leader>ff <cmd>Telescope find_files<cr>
      nnoremap <leader>fg <cmd>Telescope live_grep<cr>
      nnoremap <leader>fb <cmd>Telescope buffers<cr>
      nnoremap <leader>fh <cmd>Telescope help_tags<cr>
      nnoremap <leader>g :Rg<CR>
      nnoremap <leader>b :Buffers<CR>

      " Clear search highlight
      nnoremap <leader>h :nohlsearch<CR>

      " Window navigation
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l

      " Buffer navigation
      nnoremap <tab> :bnext<cr>
      nnoremap <S-tab> :bprev<cr>

      " Maintain visual selection after indenting
      vnoremap < <gv
      vnoremap > >gv

      " Move lines up and down
      nnoremap <A-j> :m .+1<CR>==
      nnoremap <A-k> :m .-2<CR>==
      vnoremap <A-j> :m '>+1<CR>gv=gv
      vnoremap <A-k> :m '<-2<CR>gv=gv

      " Yank to end of line
      nnoremap Y y$

      " Move by display lines when wrapping
      nnoremap j gj
      nnoremap k gk

      " Clipboard operations
      nnoremap <Leader>, "+gP
      xnoremap <Leader>. "+y

      " Terminal settings for Neovim
      if has('nvim')
        tnoremap <Esc> <C-\><C-n>
        autocmd TermOpen * startinsert
      endif

      " Auto-save on focus lost
      autocmd FocusLost * silent! wa

      " Highlight yanked text
      autocmd TextYankPost * silent! lua vim.highlight.on_yank()

      " Change cursor on mode
      autocmd InsertEnter * set cul
      autocmd InsertLeave * set nocul

      " Startify configuration
      let g:startify_session_dir = expand('~/.local/share/nvim/session')
      let g:startify_session_persistence = 1
      let g:startify_session_autoload = 0
      let g:startify_fortune_use_unicode = 1

      let g:startify_lists = [
        \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
        \ ]

      let g:startify_bookmarks = [
        \ '~/.local/share/src',
        \ ]
    '';

    extraLuaConfig = ''
      -- LSP Configuration using Neovim 0.11+ native API
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Common on_attach function
      local on_attach = function(client, bufnr)
        local opts = { noremap=true, silent=true, buffer=bufnr }
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)
      end

      -- Language servers using new vim.lsp.config API
      -- Python
      vim.lsp.config.pyright = {
        cmd = { 'pyright-langserver', '--stdio' },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Bash
      vim.lsp.config.bashls = {
        cmd = { 'bash-language-server', 'start' },
        filetypes = { 'sh' },
        root_markers = { '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Terraform
      vim.lsp.config.terraformls = {
        cmd = { 'terraform-ls', 'serve' },
        filetypes = { 'terraform', 'tf' },
        root_markers = { '.terraform', '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Markdown
      vim.lsp.config.marksman = {
        cmd = { 'marksman', 'server' },
        filetypes = { 'markdown', 'markdown.mdx' },
        root_markers = { '.git', '.marksman.toml' },
        capabilities = capabilities,
        on_attach = on_attach,
      }

      -- Nix
      vim.lsp.config.nil_ls = {
        cmd = { 'nil' },
        filetypes = { 'nix' },
        root_markers = { 'flake.nix', '.git' },
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          ['nil'] = {
            formatting = {
              command = { "nixfmt" },
            },
          },
        },
      }

      -- Enable LSP servers for matching filetypes
      vim.lsp.enable('pyright')
      vim.lsp.enable('bashls')
      vim.lsp.enable('terraformls')
      vim.lsp.enable('marksman')
      vim.lsp.enable('nil_ls')

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

      -- Use buffer source for `/` and `?`
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })

      -- Use cmdline & path source for ':'
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        })
      })

      -- Treesitter configuration
      require('nvim-treesitter.configs').setup {
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "gnn",
            node_incremental = "grn",
            scope_incremental = "grc",
            node_decremental = "grm",
          },
        },
      }

      -- Lualine setup
      require('lualine').setup {
        options = {
          theme = 'gruvbox-material',
          component_separators = { left = "", right = ""},
          section_separators = { left = "", right = ""},
        }
      }

      -- Indent blankline
      require("ibl").setup({
        scope = {
          enabled = true,
          show_start = true,
          show_end = false,
        }
      })

      -- Which-key
      require("which-key").setup({
        win = {
          border = "rounded",
          position = "bottom",
          margin = { 1, 0, 1, 0 },
          padding = { 2, 2, 2, 2 },
        },
      })

      -- Telescope setup
      require('telescope').setup{
        defaults = {
          mappings = {
            i = {
              ["<esc>"] = require('telescope.actions').close
            }
          }
        }
      }

      -- Toggle terminal setup
      require("toggleterm").setup{
        size = 20,
        open_mapping = [[<c-\>]],
        direction = 'float',
        float_opts = {
          border = 'curved',
        }
      }
    '';
  };
}
