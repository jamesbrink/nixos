# Productivity apps to enhance macOS workflow
# Clipboard manager, window switcher, keyboard remapper
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Install productivity apps via Homebrew
  homebrew.casks = [
    "maccy" # Clipboard manager (cliphist equivalent)
    "alt-tab" # Windows-style alt-tab with previews
    "karabiner-elements" # Advanced keyboard remapping
  ];

  # Maccy configuration
  # TODO: The automatic restart doesn't reliably apply settings - hotkey must be set manually in Maccy preferences
  # User must manually open Maccy settings and set cmd+shift+V after first install
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Configuring Maccy clipboard manager..."

    # Set Maccy defaults (runs for current user)
    # Note: Maccy is a sandboxed app, so config goes to ~/Library/Containers/org.p0deje.Maccy/
    sudo -u jamesbrink defaults write org.p0deje.Maccy KeyboardShortcuts_activate "Command+Shift+V"
    sudo -u jamesbrink defaults write org.p0deje.Maccy historySize 200
    sudo -u jamesbrink defaults write org.p0deje.Maccy pasteByDefault true
    sudo -u jamesbrink defaults write org.p0deje.Maccy fuzzySearch true

    # Restart Maccy to pick up new configuration if it's running
    # NOTE: This doesn't always work - see TODO above
    if pgrep -x "Maccy" > /dev/null; then
      echo "Restarting Maccy to apply configuration..."
      sudo -u jamesbrink killall Maccy 2>/dev/null || true
      sleep 1
      sudo -u jamesbrink open -a Maccy
    fi

    echo "Maccy configuration complete (hotkey may need manual setup)"
  '';
}
