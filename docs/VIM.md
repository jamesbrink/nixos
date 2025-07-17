# Neovim Configuration Guide

This guide covers the Neovim configuration for the jamesbrink user profile across all NixOS/Darwin hosts.

## Leader Keys

- **Leader**: `,` (comma)
- **Local Leader**: `<Space>`

## Essential Hotkeys

### Navigation

| Key            | Action                                                  |
| -------------- | ------------------------------------------------------- |
| `j` / `k`      | Move down/up by display lines (works with wrapped text) |
| `h` / `l`      | Move left/right                                         |
| `0` / `$`      | Beginning/end of line                                   |
| `gg` / `G`     | Beginning/end of file                                   |
| `Ctrl-h/j/k/l` | Move between splits/windows                             |
| `Tab`          | Next buffer                                             |
| `Shift-Tab`    | Previous buffer                                         |

### File Operations

| Key    | Action                                  |
| ------ | --------------------------------------- |
| `,ff`  | Find files (Telescope fuzzy finder)     |
| `,fg`  | Live grep - search in files (Telescope) |
| `,fb`  | Browse open buffers (Telescope)         |
| `,fh`  | Help tags (Telescope)                   |
| `:Ex`  | Open netrw file explorer                |
| `:Vex` | Open netrw in vertical split            |
| `:Sex` | Open netrw in horizontal split          |

### Editing

| Key      | Action                     |
| -------- | -------------------------- |
| `i`      | Insert mode before cursor  |
| `a`      | Insert mode after cursor   |
| `o`      | New line below and insert  |
| `O`      | New line above and insert  |
| `Esc`    | Return to normal mode      |
| `u`      | Undo                       |
| `Ctrl-r` | Redo                       |
| `.`      | Repeat last action         |
| `Y`      | Yank (copy) to end of line |
| `dd`     | Delete line                |
| `yy`     | Yank line                  |
| `p`      | Paste after cursor         |
| `P`      | Paste before cursor        |

### Clipboard Integration

| Key  | Action                                           |
| ---- | ------------------------------------------------ |
| `,,` | Paste from system clipboard                      |
| `,.` | Copy selection to system clipboard (visual mode) |

### Window Management

| Key         | Action              |
| ----------- | ------------------- |
| `,q`        | Quit current window |
| `:sp`       | Horizontal split    |
| `:vsp`      | Vertical split      |
| `Ctrl-w =`  | Equal size splits   |
| `Ctrl-w _`  | Maximize height     |
| `Ctrl-w \|` | Maximize width      |

### Search

| Key | Action                   |
| --- | ------------------------ |
| `/` | Search forward           |
| `?` | Search backward          |
| `n` | Next match               |
| `N` | Previous match           |
| `*` | Search word under cursor |

### Advanced

| Key            | Action                                        |
| -------------- | --------------------------------------------- |
| `w!!`          | Save file with sudo (when you forgot to sudo) |
| `:set paste`   | Enable paste mode (preserves formatting)      |
| `:set nopaste` | Disable paste mode                            |

## Visual Mode

| Key       | Action                    |
| --------- | ------------------------- |
| `v`       | Character visual mode     |
| `V`       | Line visual mode          |
| `Ctrl-v`  | Block visual mode         |
| `>` / `<` | Indent/unindent selection |

## Installed Plugins

### UI & Themes

- **vim-airline**: Status line with bubblegum theme
- **vim-startify**: Start screen with bookmarks (~/.local/share/src)

### Core Functionality

- **vim-sensible**: Sensible defaults
- **vim-surround**: Surround text objects (e.g., `cs"'` changes " to ')
- **vim-commentary**: Comment with `gc{motion}` or `gcc` for line
- **vim-repeat**: Repeat plugin actions with `.`
- **vim-fugitive**: Git integration
- **vim-gitgutter**: Show git changes in gutter
- **vim-tmux-navigator**: Seamless tmux/vim navigation

### File Navigation

- **telescope.nvim**: Fuzzy finder (see File Operations above)

### Language Support

- **ansible-vim**: Ansible syntax
- **nvim-sops**: SOPS encryption support
- **vim-terraform**: Terraform syntax
- **vim-markdown**: Markdown support
- **vim-nix**: Nix syntax

### LSP & Completion

- **nvim-lspconfig**: Language server protocol
- **nvim-cmp**: Autocompletion
- **nvim-treesitter**: Better syntax highlighting

## Language Servers Configured

- **Python**: pyright
- **Bash**: bash-language-server
- **Terraform**: terraform-ls
- **Markdown**: marksman
- **Nix**: nil

## Autocompletion

| Key          | Action                   |
| ------------ | ------------------------ |
| `Tab`        | Next completion item     |
| `Shift-Tab`  | Previous completion item |
| `Ctrl-Space` | Trigger completion       |
| `Ctrl-e`     | Abort completion         |
| `Enter`      | Confirm completion       |
| `Ctrl-b`     | Scroll docs up           |
| `Ctrl-f`     | Scroll docs down         |

## Configuration Details

### General Settings

- Line numbers with relative numbering
- No backup/swap files
- Tab = 8 spaces, but uses 2 spaces for indentation
- Case-insensitive search (smart case when uppercase used)
- Mouse support enabled
- No line wrapping
- Cursor line highlighting changes in insert mode

### File Type Settings

- Syntax highlighting enabled
- File type detection and indentation
- Automatic formatting for Nix files using nixfmt

## Tips & Tricks

### Quick Edits

1. `ci"` - Change inside quotes
2. `da(` - Delete around parentheses
3. `vi{` - Select inside braces
4. `cs"'` - Change surrounding quotes from " to '

### Macros

1. `qa` - Start recording macro in register 'a'
2. Perform your actions
3. `q` - Stop recording
4. `@a` - Play macro
5. `@@` - Repeat last macro

### Marks

1. `ma` - Set mark 'a' at cursor
2. `'a` - Jump to line of mark 'a'
3. `` `a`` - Jump to exact position of mark 'a'

### Registers

1. `"ayy` - Yank line into register 'a'
2. `"ap` - Paste from register 'a'
3. `:reg` - View all registers

### Quick Substitution

- `:%s/old/new/g` - Replace all in file
- `:s/old/new/g` - Replace all in line
- `:%s/old/new/gc` - Replace with confirmation

### Common Workflows

#### Git Integration (vim-fugitive)

- `:Git` or `:G` - Git status
- `:Gblame` - Git blame
- `:Gdiff` - Git diff
- `:Glog` - Git log

#### Working with Multiple Files

1. Open files: `:e filename` or `,ff`
2. Switch buffers: `Tab`/`Shift-Tab`
3. List buffers: `:ls` or `,fb`
4. Close buffer: `:bd`

#### Quick Config Access

- Edit config: `nvim ~/.config/nvim/init.lua`
- Reload config: `:source %` (when in config file)

## Troubleshooting

### If Plugins Don't Load

1. Exit Neovim
2. Run: `nvim +PlugInstall`
3. Restart Neovim

### If LSP Isn't Working

1. Check language server is installed: `which pyright` (or other LSP)
2. Check LSP status: `:LspInfo`
3. Restart LSP: `:LspRestart`

### Common Issues

- **Paste formatting issues**: Use `:set paste` before pasting
- **Can't exit**: Try `:q!` to force quit, or `ZQ`
- **Can't save**: Try `w!!` for sudo save
- **Lost in modes**: Hit `Esc` multiple times to get to normal mode

## Aliases Available

Since we set `vimAlias = true` and `viAlias = true`, all these commands run Neovim:

- `vim` → `nvim`
- `vi` → `nvim`
- `vimdiff` → `nvim -d`
