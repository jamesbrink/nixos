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

    local function runThemectl(args, successMessage)
      local cmd = string.format("/usr/bin/env themectl %s 2>&1", args)
      local output, status = hs.execute(cmd, true)
      if output and output ~= "" then
        print("themectl:", output)
      end
      if not status then
        hs.notify.new({title = "themectl", informativeText = "Command failed: " .. args}):send()
      elseif successMessage then
        hs.notify.new({title = "themectl", informativeText = successMessage}):send()
      end
      return status
    end

    -- Unified theme cycling (Alacritty + Ghostty + VSCode + Wallpaper + System Appearance)
    -- Bind Cmd+Shift+T to cycle all themes via themectl
    hs.hotkey.bind({"cmd", "shift"}, "T", function()
      runThemectl("cycle", "Cycled theme")
    end)

    -- Toggle between BSP tiling and native macOS mode
    -- Bind Cmd+Shift+Space to toggle via themectl
    hs.hotkey.bind({"cmd", "shift"}, "space", function()
      runThemectl("macos-mode toggle", "Toggled window manager mode")
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
