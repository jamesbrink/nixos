# Hammerspoon configuration for macOS automation
{
  config,
  lib,
  pkgs,
  hotkeysBundle ? null,
  ...
}:

let
  themectlCfg = config.programs.themectl or { };
  fallbackStatePath = "${config.home.homeDirectory}/.config/themes/.current-theme";
  fallbackMetadataPath = "${config.home.homeDirectory}/.config/themectl/themes.json";
  themeStatePath = themectlCfg.stateFile or fallbackStatePath;
  themeMetadataPath = themectlCfg.metadataPath or fallbackMetadataPath;
  resolvedHotkeys =
    if hotkeysBundle != null then hotkeysBundle else import ../../../lib/hotkeys.nix { inherit pkgs; };
  hotkeysData = resolvedHotkeys.data;
  darwinPlatform = hotkeysData.platforms.darwin;
  darwinMode = darwinPlatform.default_mode or "bsp";
  expandBindings =
    bindings:
    lib.foldl' (
      acc: name:
      let
        value = bindings.${name};
        path = lib.splitString "." name;
      in
      lib.recursiveUpdate acc (lib.setAttrByPath path value)
    ) { } (builtins.attrNames bindings);
  darwinBindings = expandBindings darwinPlatform.modes.${darwinMode}.bindings;
  hsHotkey =
    chord:
    let
      parts = map lib.strings.toLower (lib.splitString "+" chord);
      keyToken = lib.last parts;
      mods = lib.init parts;
      key = if lib.stringLength keyToken == 1 then lib.strings.toUpper keyToken else keyToken;
      modList =
        if mods == [ ] then "{ }" else "{ " + (lib.concatStringsSep ", " (map (m: ''"${m}"'') mods)) + " }";
    in
    {
      mods = modList;
      key = key;
    };
  hsThemeCycle = hsHotkey darwinBindings.theme.cycle;
  hsModeToggle = hsHotkey darwinBindings.macos_mode.toggle;
in
{
  # Deploy hammerspoon init.lua
  home.file.".hammerspoon/init.lua".text = ''
    -- Hammerspoon configuration
    -- Reload config automatically on change
    hs.loadSpoon("ReloadConfiguration")
    spoon.ReloadConfiguration:start()

    local THEME_STATE = "${themeStatePath}"
    local THEME_METADATA = "${themeMetadataPath}"

    local function readFile(path)
      local handle = io.open(path, "r")
      if not handle then
        return nil
      end
      local contents = handle:read("*a")
      handle:close()
      return contents
    end

    local function slugToDisplayName(slug)
      local raw = readFile(THEME_METADATA)
      if not raw then
        return slug
      end
      local ok, parsed = pcall(hs.json.decode, raw)
      if not ok or type(parsed) ~= "table" then
        return slug
      end
      local themes = parsed.themes
      if type(themes) ~= "table" then
        themes = parsed
      end
      if type(themes) ~= "table" then
        return slug
      end
      for _, entry in pairs(themes) do
        if type(entry) == "table" then
          local entrySlug = entry.slug or entry.name
          if entrySlug and type(entrySlug) == "string" then
            if entrySlug:lower() == slug:lower() then
              return entry.displayName or entry.name or slug
            end
          end
        end
      end
      return slug
    end

    local function currentThemeName()
      local slug = readFile(THEME_STATE)
      if not slug then
        return nil
      end
      slug = slug:match("^%s*(.-)%s*$")
      if not slug or slug == "" then
        return nil
      end
      return slugToDisplayName(slug)
    end

    local function runThemectl(args, successMessage)
      local cmd = string.format("/usr/bin/env themectl %s 2>&1", args)
      local output, status = hs.execute(cmd, true)
      if output and output ~= "" then
        print("themectl:", output)
      end
      if not status then
        hs.notify.new({title = "themectl", informativeText = "Command failed: " .. args}):send()
      else
        local message = nil
        if type(successMessage) == "function" then
          local ok, value = pcall(successMessage, output)
          if ok then
            message = value
          end
        elseif type(successMessage) == "string" then
          message = successMessage
        end
        if message and message ~= "" then
          hs.notify.new({title = "themectl", informativeText = message}):send()
        end
      end
      return status
    end

    local function modifiersActive()
      local mods = hs.eventtap.checkKeyboardModifiers() or {}
      return mods.cmd or mods.shift or mods.alt or mods.ctrl or mods.fn
    end

    local function runAfterModifiersClear(callback)
      if type(callback) ~= "function" then
        return
      end
      if not modifiersActive() then
        callback()
        return
      end
      local poller
      poller = hs.timer.doEvery(0.05, function()
        if not modifiersActive() then
          poller:stop()
          callback()
        end
      end)
    end

    local function cycleThemes()
      runAfterModifiersClear(function()
        runThemectl("cycle", function()
          local name = currentThemeName()
          if name then
            return "Cycled to " .. name
          end
          return "Theme cycled"
        end)
      end)
    end

    local function toggleMacMode()
      runAfterModifiersClear(function()
        runThemectl("macos-mode toggle", "Toggled window manager mode")
      end)
    end

    -- Unified theme cycling (Alacritty + Ghostty + VSCode + Wallpaper + System Appearance)
    -- Bind Cmd+Shift+T to cycle all themes via themectl
    hs.hotkey.bind(${hsThemeCycle.mods}, "${hsThemeCycle.key}", cycleThemes)

    -- Toggle between BSP tiling and native macOS mode
    -- Bind Cmd+Shift+Space to toggle via themectl
    hs.hotkey.bind(${hsModeToggle.mods}, "${hsModeToggle.key}", toggleMacMode)

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
