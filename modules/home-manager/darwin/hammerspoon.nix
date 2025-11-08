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

    -- Alacritty theme cycling
    -- Bind Cmd+Shift+T to cycle themes
    hs.hotkey.bind({"cmd", "shift"}, "T", function()
      hs.task.new("${config.home.homeDirectory}/.local/bin/alacritty-cycle-theme", nil):start()
    end)

    -- Show notification on startup
    hs.notify.new({
      title = "Hammerspoon",
      informativeText = "Config loaded\nCmd+Shift+T: Cycle Alacritty theme"
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
