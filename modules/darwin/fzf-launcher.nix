# Custom fzf-based application launcher for macOS
# Provides Rofi/Walker-like experience similar to Hyprland setup
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Create launcher script that will be available system-wide
  environment.systemPackages = [
    (pkgs.writeScriptBin "macos-launcher" ''
      #!${pkgs.bash}/bin/bash

      # Get list of all .app bundles in /Applications and ~/Applications
      # Format: "App Name|/path/to/App.app"
      get_apps() {
        {
          find /Applications -maxdepth 1 -name "*.app" 2>/dev/null
          find ~/Applications -maxdepth 1 -name "*.app" 2>/dev/null
          find /System/Applications -maxdepth 1 -name "*.app" 2>/dev/null
        } | while read -r app; do
          name=$(basename "$app" .app)
          echo "$name|$app"
        done | sort -u
      }

      # Use fzf to select an application
      selected=$(get_apps | \
        ${pkgs.fzf}/bin/fzf \
          --prompt="Launch: " \
          --height=40% \
          --reverse \
          --border \
          --preview-window=hidden \
          --header="Select application to launch" \
          --delimiter="|" \
          --with-nth=1)

      # Launch the selected application
      if [ -n "$selected" ]; then
        app_path=$(echo "$selected" | cut -d'|' -f2)
        open -a "$app_path"
      fi
    '')
  ];

  # Note: Add to SKHD config to bind hotkey (e.g., cmd + d)
  # cmd - d : alacritty-cwd-launch -e macos-launcher
}
