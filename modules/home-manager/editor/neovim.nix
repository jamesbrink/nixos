{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Theme mapping for neovim colorschemes (Omarchy-style)
  # Maps our theme names to LazyVim colorschemes
  themeToColorscheme = {
    tokyo-night = "tokyonight";
    catppuccin = "catppuccin";
    gruvbox = "gruvbox";
    nord = "nordfox";
    rose-pine = "rose-pine";
  };

  # Get the selected theme from hyprland module if it exists
  # Otherwise default to tokyo-night
  selectedTheme = "tokyo-night"; # This will be dynamic later
  nvimColorscheme = themeToColorscheme.${selectedTheme} or "tokyonight";

in
{
  # LazyVim configuration directories
  xdg.configFile."nvim/lazyvim.json".text = builtins.toJSON {
    extras = [
      "lazyvim.plugins.extras.editor.neo-tree"
    ];
    install_version = 8;
    news = {
      "NEWS.md" = "99999"; # Disable news popup
    };
    version = 8;
  };

  # Colorscheme plugins configuration
  xdg.configFile."nvim/lua/plugins/colorschemes.lua".text = ''
    return {
      -- Install all colorscheme plugins for runtime theme switching
      { "folke/tokyonight.nvim", lazy = true },
      { "catppuccin/nvim", name = "catppuccin", lazy = true },
      { "ellisonleao/gruvbox.nvim", lazy = true },
      { "EdenEast/nightfox.nvim", lazy = true }, -- Provides nordfox
      { "rose-pine/neovim", name = "rose-pine", lazy = true },
      { "sainnhe/everforest", lazy = true },
      { "rebelot/kanagawa.nvim", lazy = true },
    }
  '';

  # Theme configuration template (mutable for theme switching)
  home.file.".config/nvim/lua/plugins/theme.lua.template".text = ''
    return {
      {
        "LazyVim/LazyVim",
        opts = {
          colorscheme = "${nvimColorscheme}",
          news = {
            lazyvim = false,  -- Disable LazyVim NEWS.md popup
          },
        },
      },
    }
  '';

  # Create mutable neovim theme config
  home.activation.createMutableNeovimTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CONFIG_FILE="${config.home.homeDirectory}/.config/nvim/lua/plugins/theme.lua"
    TEMPLATE_FILE="${config.home.homeDirectory}/.config/nvim/lua/plugins/theme.lua.template"
    mkdir -p "${config.home.homeDirectory}/.config/nvim/lua/plugins"

    if [[ -L "$CONFIG_FILE" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
      $DRY_RUN_CMD rm -f "$CONFIG_FILE"
      $DRY_RUN_CMD cp "$TEMPLATE_FILE" "$CONFIG_FILE"
      $DRY_RUN_CMD chmod 644 "$CONFIG_FILE"
      echo "Created mutable Neovim theme config"
    fi
  '';

  # Disable animated scrolling (Omarchy preference)
  xdg.configFile."nvim/lua/plugins/snacks-animated-scrolling-off.lua".text = ''
    return {
      "folke/snacks.nvim",
      opts = {
        scroll = {
          enabled = false, -- Disable scrolling animations
        },
      },
    }
  '';

  # Transparency configuration (Omarchy-style)
  xdg.configFile."nvim/plugin/after/transparency.lua".text = ''
    -- transparent background
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
    vim.api.nvim_set_hl(0, "Terminal", { bg = "none" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
    vim.api.nvim_set_hl(0, "FoldColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "Folded", { bg = "none" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
    vim.api.nvim_set_hl(0, "WhichKeyFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "none" })
    vim.api.nvim_set_hl(0, "TelescopePromptBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "TelescopePromptTitle", { bg = "none" })

    -- transparent background for neotree
    vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })
    vim.api.nvim_set_hl(0, "NeoTreeVertSplit", { bg = "none" })
    vim.api.nvim_set_hl(0, "NeoTreeWinSeparator", { bg = "none" })
    vim.api.nvim_set_hl(0, "NeoTreeEndOfBuffer", { bg = "none" })

    -- transparent background for nvim-tree
    vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NvimTreeVertSplit", { bg = "none" })
    vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { bg = "none" })

    -- transparent notify background
    vim.api.nvim_set_hl(0, "NotifyINFOBody", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyERRORBody", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyWARNBody", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyTRACEBody", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyINFOTitle", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyERRORTitle", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyWARNTitle", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyTRACETitle", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyINFOBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyERRORBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyWARNBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { bg = "none" })
  '';

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # LazyVim distribution (Omarchy-style)
    # Use the lazyvim package which includes lazy.nvim and LazyVim starter
    package = pkgs.neovim-unwrapped;

    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nil # Nix LSP
      nodePackages.bash-language-server
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # HTML/CSS/JSON
      python3Packages.python-lsp-server
      terraform-ls
      marksman # Markdown LSP

      # Formatters
      nixfmt-rfc-style
      stylua
      black
      isort
      shfmt
      nodePackages.prettier

      # Tools
      ripgrep
      fd
      git
      lazygit
    ];

    extraLuaConfig = ''
      -- Bootstrap lazy.nvim
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = "https://github.com/folke/lazy.nvim.git"
        local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
        if vim.v.shell_error ~= 0 then
          vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
          }, true, {})
          vim.fn.getchar()
          os.exit(1)
        end
      end
      vim.opt.rtp:prepend(lazypath)

      -- Setup lazy.nvim with LazyVim
      require("lazy").setup({
        spec = {
          -- Import LazyVim and its plugins
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          -- Import user plugins from lua/plugins
          { import = "plugins" },
        },
        defaults = {
          lazy = false,
          version = false,
        },
        checker = { enabled = true },
        performance = {
          rtp = {
            disabled_plugins = {
              "gzip",
              "tarPlugin",
              "tohtml",
              "tutor",
              "zipPlugin",
            },
          },
        },
      })

      -- Basic settings
      vim.opt.relativenumber = false
      vim.opt.clipboard = "unnamedplus"
    '';
  };
}
