# Tmux configuration for all users
{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    shortcut = "b";
    terminal = "screen-256color";
    historyLimit = 10000;

    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      sensible
      yank
      resurrect
      continuum
      pain-control
      prefix-highlight
    ];

    extraConfig = ''
      # Enable true colors
      set-option -ga terminal-overrides ",*256col*:Tc"
      set-option -ga terminal-overrides ",alacritty:Tc"

      # Mouse support
      set -g mouse on

      # Status bar
      set -g status-position top
      set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
      set -g status-left '#[fg=#89b4fa,bold]#S #[fg=#cdd6f4]• '
      set -g status-right '#[fg=#f38ba8]#(whoami)#[fg=#cdd6f4]@#[fg=#a6e3a1]#h #[fg=#cdd6f4]• #[fg=#f9e2af]%Y-%m-%d %H:%M'
      set -g status-left-length 50
      set -g status-right-length 50

      # Window status
      setw -g window-status-current-style 'fg=#1e1e2e bg=#89b4fa bold'
      setw -g window-status-current-format ' #I:#W#F '
      setw -g window-status-style 'fg=#cdd6f4'
      setw -g window-status-format ' #I:#W#F '

      # Pane borders
      set -g pane-border-style 'fg=#45475a'
      set -g pane-active-border-style 'fg=#89b4fa'

      # Message style
      set -g message-style 'fg=#1e1e2e bg=#f9e2af bold'

      # Copy mode
      setw -g mode-style 'fg=#1e1e2e bg=#cba6f7 bold'

      # Window/pane management
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Resize panes with vim keys
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Quick window selection
      bind -r C-h select-window -t :-
      bind -r C-l select-window -t :+

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

      # Copy mode vi bindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi Escape send-keys -X cancel

      # Platform-specific clipboard integration
      ${
        if pkgs.stdenv.isDarwin then
          ''
            bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
            bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
            bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
          ''
        else
          ''
            bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
            bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
            bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
          ''
      }

      # Activity monitoring
      setw -g monitor-activity on
      set -g visual-activity off

      # Auto-rename windows
      setw -g automatic-rename on
      set -g set-titles on
      set -g set-titles-string '#h ❐ #S ● #I #W'

      # Plugin configurations
      set -g @resurrect-capture-pane-contents 'on'
      set -g @continuum-restore 'on'
      set -g @continuum-boot 'on'
      set -g @prefix_highlight_show_copy_mode 'on'
      set -g @prefix_highlight_copy_mode_attr 'fg=black,bg=yellow,bold'
    '';
  };
}
