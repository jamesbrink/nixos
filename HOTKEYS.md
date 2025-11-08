# HOTKEYS Cheat Sheet

Quick reference for macOS (Yabai), Hyprland, tmux, and Vim/Neovim hotkeys.

---

## macOS Window Manager (Yabai + SKHD)

**Modifier:** `Cmd` (Command key)

### Applications

- `Cmd+Return` - Terminal (Alacritty)
- `Cmd+Shift+F` - File manager (Finder)
- `Cmd+Shift+B` - Browser (Chrome), `Cmd+Shift+Alt+B` - Browser incognito
- `Cmd+Shift+M` - Spotify
- `Cmd+Shift+N` - Neovim (terminal)
- `Cmd+Shift+O` - Obsidian
- `Cmd+Shift+Y` - YouTube
- `Cmd+Shift+T` - Theme cycling
- `Cmd+Alt+T` - btop (system monitor)

### Window Management

- `Cmd+W` - Close window
- `Cmd+T` - Toggle float
- `Cmd+F` - Fullscreen (zoom), `Cmd+Ctrl+F` - Native fullscreen
- `Cmd+J` - Toggle split orientation
- `Cmd+Arrows` - Move focus between windows
- `Cmd+Shift+Arrows` - Swap windows
- `Cmd+Minus/Equal` - Resize width (-40/+40px)
- `Cmd+Shift+Minus/Equal` - Resize height (-40/+40px)

### Workspaces (Spaces)

- `Cmd+1-9,0` - Switch to workspace 1-10
- `Cmd+Shift+1-9,0` - Move window to workspace 1-10
- `Cmd+Tab` - Next workspace, `Cmd+Shift+Tab` - Previous workspace

### Window Cycling

- `Alt+Tab` - Cycle next window, `Alt+Shift+Tab` - Cycle previous

### Layout Management

- `Cmd+Ctrl+Space` - Toggle between tiling (BSP) and floating (normal macOS)
- `Cmd+R` - Rotate tree 90°
- `Cmd+X` - Mirror tree X-axis, `Cmd+Y` - Mirror tree Y-axis
- `Cmd+E` - Balance windows

### Clipboard & Productivity

- `Cmd+Shift+V` - Clipboard history (Maccy)

### Yabai Control

- `Cmd+Ctrl+R` - Restart yabai
- `Cmd+Ctrl+Q` - Stop/start yabai

### Mouse Actions

- `Cmd+Left Drag` - Move window
- `Cmd+Right Drag` - Resize window

---

## Hyprland Window Manager

**Modifier:** `Super` (Windows key)

### Applications

- `Super+Return` - Terminal (opens in current directory)
- `Super+Shift+F` - File manager (Thunar)
- `Super+Shift+B` - Browser, `Super+Shift+Alt+B` - Browser incognito
- `Super+Shift+M` - Spotify
- `Super+Shift+N` - Neovim (terminal)
- `Super+Shift+T` - btop (system monitor)
- `Super+Shift+D` - lazydocker
- `Super+Shift+G` - Signal
- `Super+Shift+O` - Obsidian
- `Super+Shift+Y` - YouTube

### Menus & Launchers

- `Super+Space` - Application launcher (Walker)
- `Super+Ctrl+E` - Emoji picker
- `Super+Escape` - Power menu (lock/logout/shutdown/reboot)
- `Super+K` - Keybindings help menu
- `Super+Shift+Space` - Toggle status bar (Waybar)

### Window Management

- `Super+W` - Kill active window
- `Super+T` - Toggle floating, `Super+J` - Toggle split direction
- `Super+P` - Pseudo-tile mode
- `Super+F` - Fullscreen, `Super+Ctrl+F` - Maximize
- `Super+Arrows` - Move focus between windows
- `Super+Shift+Arrows` - Swap windows
- `Super+Minus/Equal` - Resize width (-40/+40px)
- `Super+Shift+Minus/Equal` - Resize height (-40/+40px)

### Workspaces

- `Super+1-9,0` - Switch to workspace 1-10
- `Super+Shift+1-9,0` - Move window to workspace 1-10
- `Super+Tab` - Next workspace, `Super+Shift+Tab` - Previous workspace
- `Super+Scroll` - Scroll through workspaces

### Window Cycling

- `Alt+Tab` - Cycle next window, `Alt+Shift+Tab` - Cycle previous

### Window Groups (Tabbed)

- `Super+G` - Toggle group (tabbed mode)
- `Super+Alt+Arrows` - Move window into group
- `Super+Alt+Tab` - Next tab, `Super+Alt+Shift+Tab` - Previous tab

### Screenshots

- `PrintScreen` - Annotate region, `Shift+PrintScreen` - Annotate window
- `Super+S` - Annotate region, `Super+Shift+S` - Annotate window, `Super+Ctrl+S` - Annotate full
- `Super+Ctrl+Shift+3` - Full screen (direct), `4` - Region (direct), `5` - Window (direct)

### Screen Recording

- `Super+R` - Record region, `Super+Shift+R` - Record region with audio
- `Super+Ctrl+R` - Record screen, `Super+Ctrl+Shift+R` - Record screen with audio
- `Alt+PrintScreen` - Record region, `Alt+Shift+PrintScreen` - Record region with audio
- **Stop:** Press same key combo while recording

### Clipboard & Notifications

- `Super+Ctrl+V` - Clipboard history
- `Super+Comma` - Dismiss notification, `Super+Shift+Comma` - Dismiss all
- `Super+Ctrl+Comma` - Toggle Do Not Disturb

### Theme & Appearance

- `Super+Ctrl+Space` - Rotate wallpaper
- `Super+Shift+Ctrl+Space` - Theme picker

### Media Keys

- `XF86AudioRaiseVolume/LowerVolume` - Volume up/down
- `XF86AudioMute` - Toggle mute, `XF86AudioMicMute` - Toggle mic mute
- `XF86AudioPlay/Next/Prev` - Media playback controls
- `XF86MonBrightnessUp/Down` - Screen brightness

### Mouse Actions

- `Super+Left Drag` - Move window
- `Super+Right Drag` - Resize window
- `3-Finger Swipe` - Switch workspace (touchpad)

---

## Tmux Hotkeys

**Prefix:** `Ctrl+B` (all commands below require prefix first)

### Session Management

- `d` - Detach from session
- `$` - Rename session
- `s` - List sessions

### Window Management

- `c` - Create new window (opens in current directory)
- `&` - Kill current window
- `,` - Rename window
- `w` - List windows
- `Ctrl+H` - Previous window (repeatable)
- `Ctrl+L` - Next window (repeatable)
- `0-9` - Switch to window by number

### Pane Management

- `|` - Split pane horizontally (opens in current directory)
- `-` - Split pane vertically (opens in current directory)
- `x` - Kill pane
- `z` - Toggle pane zoom (fullscreen)
- `q` - Show pane numbers
- `o` - Cycle through panes
- `!` - Break pane into window

#### Vim-style Navigation (vim-tmux-navigator)

- `Ctrl+H` - Navigate to left pane
- `Ctrl+J` - Navigate to down pane
- `Ctrl+K` - Navigate to up pane
- `Ctrl+L` - Navigate to right pane

#### Resize Panes (repeatable)

- `H` - Resize pane left
- `J` - Resize pane down
- `K` - Resize pane up
- `L` - Resize pane right

#### Layout Management

- `Space` - Cycle through layouts
- `Alt+1` - Even horizontal layout
- `Alt+2` - Even vertical layout
- `Alt+3` - Main horizontal
- `Alt+4` - Main vertical
- `Alt+5` - Tiled layout

### Copy Mode (Vi Mode)

- `[` - Enter copy mode
- `v` - Begin selection (in copy mode)
- `Ctrl+V` - Rectangle selection (in copy mode)
- `y` - Copy selection to clipboard
- `Escape` - Cancel selection
- `]` - Paste from tmux buffer

#### Navigation in Copy Mode

- `h/j/k/l` - Move cursor (vim keys)
- `w` - Next word
- `b` - Previous word
- `0` - Start of line
- `$` - End of line
- `g` - Top of buffer
- `G` - Bottom of buffer
- `/` - Search forward
- `?` - Search backward
- `n` - Next search match
- `N` - Previous search match

### Misc

- `r` - Reload tmux config
- `?` - List all keybindings
- `:` - Enter command mode

---

## Vim/Neovim Hotkeys (LazyVim)

**Leader Key:** `Space`

### Basic Vim Motions

- `h/j/k/l` - Left/Down/Up/Right
- `w` - Next word
- `b` - Previous word
- `e` - End of word
- `0` - Start of line
- `$` - End of line
- `gg` - Top of file
- `G` - Bottom of file
- `%` - Jump to matching bracket
- `Ctrl+D` - Scroll down half page
- `Ctrl+U` - Scroll up half page
- `Ctrl+F` - Page down
- `Ctrl+B` - Page up

### Editing

- `i` - Insert before cursor
- `a` - Insert after cursor
- `I` - Insert at start of line
- `A` - Insert at end of line
- `o` - New line below
- `O` - New line above
- `x` - Delete character
- `dd` - Delete line
- `dw` - Delete word
- `d$` - Delete to end of line
- `cc` - Change line
- `cw` - Change word
- `yy` - Yank (copy) line
- `yw` - Yank word
- `p` - Paste after cursor
- `P` - Paste before cursor
- `u` - Undo
- `Ctrl+R` - Redo
- `.` - Repeat last command

### Visual Mode

- `v` - Visual mode (character)
- `V` - Visual mode (line)
- `Ctrl+V` - Visual block mode
- `>` - Indent selection
- `<` - Unindent selection
- `y` - Yank selection
- `d` - Delete selection

### Search & Replace

- `/pattern` - Search forward
- `?pattern` - Search backward
- `n` - Next match
- `N` - Previous match
- `*` - Search word under cursor
- `:%s/old/new/g` - Replace all in file
- `:%s/old/new/gc` - Replace all with confirmation

### LazyVim Specific

#### File Navigation

- `<Leader>ff` - Find files (Telescope)
- `<Leader>fg` - Live grep (search in files)
- `<Leader>fb` - Find buffers
- `<Leader>fr` - Recent files
- `<Leader>e` - Toggle file explorer (Neo-tree)

#### Buffer Management

- `<Leader>bd` - Delete buffer
- `<Leader>bb` - Switch buffer
- `[b` - Previous buffer
- `]b` - Next buffer

#### Window Management

- `<Leader>w` - Window commands
- `<Leader>ww` - Switch windows
- `<Leader>wd` - Delete window
- `<Leader>ws` - Split window
- `<Leader>wv` - Vertical split
- `Ctrl+H/J/K/L` - Navigate between windows

#### Code Navigation

- `gd` - Go to definition
- `gr` - Go to references
- `K` - Hover documentation
- `<Leader>ca` - Code actions
- `<Leader>rn` - Rename symbol
- `[d` - Previous diagnostic
- `]d` - Next diagnostic

#### LSP & Formatting

- `<Leader>cf` - Format document
- `<Leader>cd` - Line diagnostics
- `<Leader>cl` - Linter info

#### Git Integration

- `<Leader>gg` - LazyGit
- `<Leader>gb` - Git blame line
- `]h` - Next git hunk
- `[h` - Previous git hunk

#### Misc

- `<Leader>qq` - Quit all
- `<Leader>ur` - Toggle relative line numbers
- `<Leader>uw` - Toggle word wrap
- `<Leader>us` - Toggle spelling
- `<Leader>l` - Lazy plugin manager

### Saving & Quitting

- `:w` - Save
- `:q` - Quit
- `:wq` or `ZZ` - Save and quit
- `:q!` or `ZQ` - Quit without saving
- `:wa` - Save all buffers
- `:qa` - Quit all

---

## Tips

### Tmux

- **Mouse mode is enabled** - Click panes to switch, drag borders to resize
- **Auto-restore sessions** - Tmux resurrect/continuum saves sessions automatically
- **Clipboard integration** - Copy mode automatically copies to system clipboard

### Neovim

- **LazyVim** - Press `<Leader>l` to open plugin manager
- **Which-key** - Press `<Leader>` and wait to see available keybindings
- **Transparent background** - Terminal transparency is enabled
- **System clipboard** - Yank/paste operations use system clipboard (`unnamedplus`)

---

**Note:** This configuration is managed via NixOS in:

- Tmux: `modules/home-manager/shell/tmux.nix`
- Neovim: `modules/home-manager/editor/neovim.nix`
