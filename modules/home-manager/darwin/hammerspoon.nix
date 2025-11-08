# Hammerspoon configuration for macOS automation
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Deploy hammerspoon init.lua
  home.file.".hammerspoon/init.lua".text = ''
    -- Hammerspoon configuration
    -- Reload config automatically on change
    hs.loadSpoon("ReloadConfiguration")
    spoon.ReloadConfiguration:start()

    -- Unified theme cycling (Alacritty + Ghostty + VSCode + Wallpaper + System Appearance)
    -- Bind Cmd+Shift+T to cycle all themes
    hs.hotkey.bind({"cmd", "shift"}, "T", function()
      local output, status = hs.execute("${config.home.homeDirectory}/.local/bin/cycle-theme 2>&1", true)
      if output and output ~= "" then
        print("Theme cycle output:", output)
      end
      if not status then
        hs.notify.new({title = "Theme Error", informativeText = "Script failed"}):send()
      end
    end)

    local function reloadGhostty()
      hs.osascript.applescript([[
        tell application "System Events"
          if exists process "Ghostty" then
            set frontApp to first application process whose frontmost is true
            set frontName to name of frontApp
            tell application "Ghostty" to activate
            delay 0.05
            keystroke "," using {command down, shift down}
            delay 0.05
            if frontName is not "Ghostty" then
              tell application frontName to activate
            end if
          end if
        end tell
      ]])
    end

    local function setGhosttyMode(mode)
      local home = os.getenv("HOME")
      local style = mode == "bsp" and "hidden" or "transparent"
      local script = string.format([[
        /bin/bash -lc '
          CONFIG="%s/.config/ghostty/config"
          STYLE="%s"
          if [ -f "$CONFIG" ]; then
            if grep -q "^macos-titlebar-style" "$CONFIG"; then
              sed -i "" "s/^macos-titlebar-style = .*/macos-titlebar-style = %s/" "$CONFIG"
            else
              printf "\nmacos-titlebar-style = %s\n" >> "$CONFIG"
            fi
          fi
        '
      ]], home, style, style, style)
      hs.execute(script)
      reloadGhostty()
    end

    -- Toggle between BSP tiling and native macOS mode
    -- Bind Cmd+Shift+Space to toggle
    hs.hotkey.bind({"cmd", "shift"}, "space", function()
      local STATE_FILE = os.getenv("HOME") .. "/.bsp-mode-state"

      -- Read current mode
      local f = io.open(STATE_FILE, "r")
      local currentMode = "bsp"  -- default
      if f then
        currentMode = f:read("*all"):gsub("%s+", "")
        f:close()
      end

      if currentMode == "bsp" then
        -- Switch to native macOS mode
        hs.execute("launchctl unload ~/Library/LaunchAgents/org.nixos.yabai.plist 2>/dev/null || true")
        hs.execute("launchctl unload ~/Library/LaunchAgents/org.nixos.skhd.plist 2>/dev/null || true")
        hs.execute("launchctl unload ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null || true")
        hs.execute("killall yabai 2>/dev/null || true")
        hs.execute("killall skhd 2>/dev/null || true")
        hs.execute("killall sketchybar 2>/dev/null || true")

        hs.execute("defaults write com.apple.dock autohide -bool false")
        hs.execute("defaults write com.apple.finder CreateDesktop -bool true")
        hs.execute("killall Dock")
        hs.execute("killall Finder")
        setGhosttyMode("macos")

        -- Save state
        local f = io.open(STATE_FILE, "w")
        if f then
          f:write("macos")
          f:close()
        end

        hs.notify.new({title = "Window Manager", informativeText = "Native macOS mode"}):send()
      else
        -- Switch to BSP tiling mode
        hs.execute("defaults write com.apple.dock autohide -bool true")
        hs.execute("defaults write com.apple.finder CreateDesktop -bool false")
        hs.execute("killall Dock")
        hs.execute("killall Finder")

        -- Wait for Dock to restart with auto-hide
        hs.timer.doAfter(3, function()
          hs.execute("launchctl load -w ~/Library/LaunchAgents/org.nixos.sketchybar.plist 2>/dev/null || true")
          hs.execute("launchctl load -w ~/Library/LaunchAgents/org.nixos.yabai.plist 2>/dev/null || true")
          hs.execute("launchctl load -w ~/Library/LaunchAgents/org.nixos.skhd.plist 2>/dev/null || true")

          -- Load yabai scripting addition after yabai starts
          hs.timer.doAfter(1, function()
            hs.execute("sudo yabai --load-sa 2>/dev/null || true")
          end)
          setGhosttyMode("bsp")

          -- Save state
          local f = io.open(STATE_FILE, "w")
          if f then
            f:write("bsp")
            f:close()
          end

          hs.notify.new({title = "Window Manager", informativeText = "BSP tiling mode"}):send()
        end)
      end
    end)

    -- Manual Hammerspoon reload
    -- Bind Cmd+Ctrl+Option+R to reload configuration
    hs.hotkey.bind({"cmd", "ctrl", "alt"}, "R", function()
      hs.reload()
      hs.notify.new({title = "Hammerspoon", informativeText = "Config reloaded"}):send()
    end)

    -- Show notification on startup
    hs.notify.new({
      title = "Hammerspoon",
      informativeText = "Config loaded\nCmd+Shift+T: Cycle themes\nCmd+Shift+Space: Toggle WM\nCmd+Ctrl+Option+R: Reload"
    }):send()
  '';

  # Create ReloadConfiguration spoon directory
  home.file.".hammerspoon/Spoons/ReloadConfiguration.spoon/init.lua".text = ''
    local obj = {}
    obj.__index = obj
    obj.name = "ReloadConfiguration"
    obj.version = "1.0"
    obj.author = "James Brink"

    function obj:init()
      self.watch = nil
    end

    function obj:start()
      self.watch = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
        doReload = false
        for _, file in pairs(files) do
          if file:sub(-4) == ".lua" then
            doReload = true
          end
        end
        if doReload then
          hs.reload()
        end
      end):start()
    end

    function obj:stop()
      if self.watch then
        self.watch:stop()
      end
    end

    return obj
  '';
}
