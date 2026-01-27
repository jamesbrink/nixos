-- Matte Black colorscheme for Neovim
-- Custom colorscheme matching our theme system colors

local M = {}

-- Color palette from modules/themes/definitions/matte-black.nix
local colors = {
  bg = "#121212",
  bg_dark = "#0c0c0c",
  bg_light = "#1f1f1f",
  bg_highlight = "#333333",

  fg = "#bebebe",
  fg_dark = "#8a8a8d",
  fg_light = "#eaeaea",
  fg_bright = "#ffffff",

  black = "#333333",
  red = "#D35F5F",
  red_bright = "#B91C1C",
  green = "#FFC107", -- Using amber as "green" per theme
  yellow = "#b91c1c",
  yellow_bright = "#b90a0a",
  blue = "#e68e0d",
  blue_bright = "#f59e0b",
  magenta = "#D35F5F",
  magenta_bright = "#B91C1C",
  cyan = "#bebebe",
  cyan_bright = "#eaeaea",
  white = "#bebebe",
  white_bright = "#ffffff",

  gray = "#8a8a8d",
  gray_dark = "#555555",

  -- Semantic colors
  error = "#B91C1C",
  warning = "#f59e0b",
  info = "#e68e0d",
  hint = "#8a8a8d",
  success = "#FFC107",

  -- Git colors
  git_add = "#FFC107",
  git_change = "#f59e0b",
  git_delete = "#b91c1c",

  -- Selection
  selection = "#333333",
  cursor = "#eaeaea",
}

function M.setup()
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true
  vim.g.colors_name = "matte-black"

  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Editor UI
  hl("Normal", { fg = colors.fg, bg = colors.bg })
  hl("NormalNC", { fg = colors.fg, bg = colors.bg })
  hl("NormalFloat", { fg = colors.fg, bg = colors.bg_light })
  hl("FloatBorder", { fg = colors.gray, bg = colors.bg_light })
  hl("FloatTitle", { fg = colors.fg_light, bg = colors.bg_light, bold = true })
  hl("Cursor", { fg = colors.bg, bg = colors.cursor })
  hl("CursorLine", { bg = colors.bg_highlight })
  hl("CursorColumn", { bg = colors.bg_highlight })
  hl("ColorColumn", { bg = colors.bg_light })
  hl("LineNr", { fg = colors.gray_dark })
  hl("CursorLineNr", { fg = colors.fg_light, bold = true })
  hl("SignColumn", { fg = colors.fg_dark, bg = colors.bg })
  hl("VertSplit", { fg = colors.bg_highlight })
  hl("WinSeparator", { fg = colors.bg_highlight })
  hl("Folded", { fg = colors.gray, bg = colors.bg_light })
  hl("FoldColumn", { fg = colors.gray })
  hl("NonText", { fg = colors.gray_dark })
  hl("SpecialKey", { fg = colors.gray_dark })
  hl("Whitespace", { fg = colors.gray_dark })
  hl("EndOfBuffer", { fg = colors.bg })

  -- Popup menu
  hl("Pmenu", { fg = colors.fg, bg = colors.bg_light })
  hl("PmenuSel", { fg = colors.fg_bright, bg = colors.bg_highlight })
  hl("PmenuSbar", { bg = colors.bg_light })
  hl("PmenuThumb", { bg = colors.gray })

  -- Search & Visual
  hl("Search", { fg = colors.bg, bg = colors.blue_bright })
  hl("IncSearch", { fg = colors.bg, bg = colors.green })
  hl("CurSearch", { fg = colors.bg, bg = colors.green })
  hl("Substitute", { fg = colors.bg, bg = colors.red })
  hl("Visual", { bg = colors.selection })
  hl("VisualNOS", { bg = colors.selection })

  -- Messages
  hl("ModeMsg", { fg = colors.fg_light, bold = true })
  hl("MsgArea", { fg = colors.fg })
  hl("MoreMsg", { fg = colors.blue })
  hl("Question", { fg = colors.blue })
  hl("ErrorMsg", { fg = colors.error })
  hl("WarningMsg", { fg = colors.warning })

  -- Statusline & Tabline
  hl("StatusLine", { fg = colors.fg, bg = colors.bg_light })
  hl("StatusLineNC", { fg = colors.gray, bg = colors.bg_dark })
  hl("TabLine", { fg = colors.gray, bg = colors.bg_dark })
  hl("TabLineFill", { bg = colors.bg_dark })
  hl("TabLineSel", { fg = colors.fg_light, bg = colors.bg })
  hl("WinBar", { fg = colors.fg, bg = colors.bg })
  hl("WinBarNC", { fg = colors.gray, bg = colors.bg })

  -- Diff
  hl("DiffAdd", { fg = colors.git_add, bg = "#1a2a1a" })
  hl("DiffChange", { fg = colors.git_change, bg = "#2a2a1a" })
  hl("DiffDelete", { fg = colors.git_delete, bg = "#2a1a1a" })
  hl("DiffText", { fg = colors.fg_bright, bg = "#3a3a2a" })

  -- Spelling
  hl("SpellBad", { sp = colors.error, undercurl = true })
  hl("SpellCap", { sp = colors.warning, undercurl = true })
  hl("SpellLocal", { sp = colors.info, undercurl = true })
  hl("SpellRare", { sp = colors.hint, undercurl = true })

  -- Syntax highlighting
  hl("Comment", { fg = colors.gray, italic = true })
  hl("Constant", { fg = colors.blue_bright })
  hl("String", { fg = colors.green })
  hl("Character", { fg = colors.green })
  hl("Number", { fg = colors.blue_bright })
  hl("Boolean", { fg = colors.blue_bright })
  hl("Float", { fg = colors.blue_bright })

  hl("Identifier", { fg = colors.fg })
  hl("Function", { fg = colors.blue })

  hl("Statement", { fg = colors.red })
  hl("Conditional", { fg = colors.red })
  hl("Repeat", { fg = colors.red })
  hl("Label", { fg = colors.red })
  hl("Operator", { fg = colors.fg_light })
  hl("Keyword", { fg = colors.red })
  hl("Exception", { fg = colors.red })

  hl("PreProc", { fg = colors.blue })
  hl("Include", { fg = colors.red })
  hl("Define", { fg = colors.red })
  hl("Macro", { fg = colors.blue })
  hl("PreCondit", { fg = colors.red })

  hl("Type", { fg = colors.green })
  hl("StorageClass", { fg = colors.red })
  hl("Structure", { fg = colors.green })
  hl("Typedef", { fg = colors.green })

  hl("Special", { fg = colors.blue })
  hl("SpecialChar", { fg = colors.blue_bright })
  hl("Tag", { fg = colors.red })
  hl("Delimiter", { fg = colors.fg })
  hl("SpecialComment", { fg = colors.gray })
  hl("Debug", { fg = colors.warning })

  hl("Underlined", { fg = colors.blue, underline = true })
  hl("Bold", { bold = true })
  hl("Italic", { italic = true })

  hl("Ignore", { fg = colors.gray_dark })
  hl("Error", { fg = colors.error })
  hl("Todo", { fg = colors.bg, bg = colors.green, bold = true })

  -- Treesitter
  hl("@comment", { link = "Comment" })
  hl("@punctuation", { fg = colors.fg })
  hl("@punctuation.bracket", { fg = colors.fg })
  hl("@punctuation.delimiter", { fg = colors.fg })
  hl("@punctuation.special", { fg = colors.blue })

  hl("@constant", { link = "Constant" })
  hl("@constant.builtin", { fg = colors.blue_bright })
  hl("@constant.macro", { link = "Macro" })

  hl("@string", { link = "String" })
  hl("@string.regex", { fg = colors.blue })
  hl("@string.escape", { fg = colors.blue_bright })
  hl("@string.special", { fg = colors.blue })

  hl("@character", { link = "Character" })
  hl("@number", { link = "Number" })
  hl("@boolean", { link = "Boolean" })
  hl("@float", { link = "Float" })

  hl("@function", { link = "Function" })
  hl("@function.builtin", { fg = colors.blue })
  hl("@function.macro", { link = "Macro" })
  hl("@function.call", { fg = colors.blue })

  hl("@method", { fg = colors.blue })
  hl("@method.call", { fg = colors.blue })

  hl("@constructor", { fg = colors.green })
  hl("@parameter", { fg = colors.fg, italic = true })

  hl("@keyword", { link = "Keyword" })
  hl("@keyword.function", { fg = colors.red })
  hl("@keyword.operator", { fg = colors.red })
  hl("@keyword.return", { fg = colors.red })

  hl("@conditional", { link = "Conditional" })
  hl("@repeat", { link = "Repeat" })
  hl("@label", { link = "Label" })
  hl("@operator", { link = "Operator" })
  hl("@exception", { link = "Exception" })

  hl("@variable", { fg = colors.fg })
  hl("@variable.builtin", { fg = colors.red })

  hl("@type", { link = "Type" })
  hl("@type.builtin", { fg = colors.green })
  hl("@type.definition", { link = "Type" })
  hl("@type.qualifier", { fg = colors.red })

  hl("@namespace", { fg = colors.fg })
  hl("@include", { link = "Include" })

  hl("@attribute", { fg = colors.blue })
  hl("@property", { fg = colors.fg })
  hl("@field", { fg = colors.fg })

  hl("@tag", { fg = colors.red })
  hl("@tag.attribute", { fg = colors.blue })
  hl("@tag.delimiter", { fg = colors.fg })

  hl("@text", { fg = colors.fg })
  hl("@text.strong", { bold = true })
  hl("@text.emphasis", { italic = true })
  hl("@text.underline", { underline = true })
  hl("@text.strike", { strikethrough = true })
  hl("@text.title", { fg = colors.fg_light, bold = true })
  hl("@text.literal", { fg = colors.green })
  hl("@text.uri", { fg = colors.blue, underline = true })
  hl("@text.reference", { fg = colors.blue })
  hl("@text.todo", { link = "Todo" })
  hl("@text.note", { fg = colors.info })
  hl("@text.warning", { fg = colors.warning })
  hl("@text.danger", { fg = colors.error })

  -- LSP Semantic tokens
  hl("@lsp.type.class", { link = "Type" })
  hl("@lsp.type.decorator", { link = "@attribute" })
  hl("@lsp.type.enum", { link = "Type" })
  hl("@lsp.type.enumMember", { link = "Constant" })
  hl("@lsp.type.function", { link = "Function" })
  hl("@lsp.type.interface", { link = "Type" })
  hl("@lsp.type.macro", { link = "Macro" })
  hl("@lsp.type.method", { link = "@method" })
  hl("@lsp.type.namespace", { link = "@namespace" })
  hl("@lsp.type.parameter", { link = "@parameter" })
  hl("@lsp.type.property", { link = "@property" })
  hl("@lsp.type.struct", { link = "Type" })
  hl("@lsp.type.type", { link = "Type" })
  hl("@lsp.type.typeParameter", { link = "Type" })
  hl("@lsp.type.variable", { link = "@variable" })

  -- Diagnostics
  hl("DiagnosticError", { fg = colors.error })
  hl("DiagnosticWarn", { fg = colors.warning })
  hl("DiagnosticInfo", { fg = colors.info })
  hl("DiagnosticHint", { fg = colors.hint })
  hl("DiagnosticUnderlineError", { sp = colors.error, undercurl = true })
  hl("DiagnosticUnderlineWarn", { sp = colors.warning, undercurl = true })
  hl("DiagnosticUnderlineInfo", { sp = colors.info, undercurl = true })
  hl("DiagnosticUnderlineHint", { sp = colors.hint, undercurl = true })
  hl("DiagnosticVirtualTextError", { fg = colors.error, bg = "#2a1a1a" })
  hl("DiagnosticVirtualTextWarn", { fg = colors.warning, bg = "#2a2a1a" })
  hl("DiagnosticVirtualTextInfo", { fg = colors.info, bg = "#2a2a1a" })
  hl("DiagnosticVirtualTextHint", { fg = colors.hint, bg = "#1a1a1a" })

  -- Git signs
  hl("GitSignsAdd", { fg = colors.git_add })
  hl("GitSignsChange", { fg = colors.git_change })
  hl("GitSignsDelete", { fg = colors.git_delete })

  -- Telescope
  hl("TelescopeNormal", { fg = colors.fg, bg = colors.bg })
  hl("TelescopeBorder", { fg = colors.gray, bg = colors.bg })
  hl("TelescopePromptNormal", { fg = colors.fg, bg = colors.bg_light })
  hl("TelescopePromptBorder", { fg = colors.gray, bg = colors.bg_light })
  hl("TelescopePromptTitle", { fg = colors.bg, bg = colors.blue })
  hl("TelescopePreviewTitle", { fg = colors.bg, bg = colors.green })
  hl("TelescopeResultsTitle", { fg = colors.bg, bg = colors.red })
  hl("TelescopeSelection", { bg = colors.bg_highlight })
  hl("TelescopeSelectionCaret", { fg = colors.blue_bright })
  hl("TelescopeMatching", { fg = colors.green, bold = true })

  -- Neo-tree
  hl("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeDirectoryName", { fg = colors.blue })
  hl("NeoTreeDirectoryIcon", { fg = colors.blue })
  hl("NeoTreeRootName", { fg = colors.fg_light, bold = true })
  hl("NeoTreeFileName", { fg = colors.fg })
  hl("NeoTreeFileIcon", { fg = colors.fg })
  hl("NeoTreeGitAdded", { fg = colors.git_add })
  hl("NeoTreeGitModified", { fg = colors.git_change })
  hl("NeoTreeGitDeleted", { fg = colors.git_delete })
  hl("NeoTreeGitUntracked", { fg = colors.gray })
  hl("NeoTreeIndentMarker", { fg = colors.gray_dark })

  -- Which-key
  hl("WhichKey", { fg = colors.blue })
  hl("WhichKeyGroup", { fg = colors.green })
  hl("WhichKeyDesc", { fg = colors.fg })
  hl("WhichKeySeparator", { fg = colors.gray })
  hl("WhichKeyFloat", { bg = colors.bg_light })

  -- Lazy.nvim
  hl("LazyH1", { fg = colors.bg, bg = colors.blue, bold = true })
  hl("LazyButton", { fg = colors.fg, bg = colors.bg_light })
  hl("LazyButtonActive", { fg = colors.bg, bg = colors.blue })
  hl("LazySpecial", { fg = colors.blue_bright })

  -- Notify
  hl("NotifyERRORBorder", { fg = colors.error })
  hl("NotifyWARNBorder", { fg = colors.warning })
  hl("NotifyINFOBorder", { fg = colors.info })
  hl("NotifyDEBUGBorder", { fg = colors.gray })
  hl("NotifyTRACEBorder", { fg = colors.hint })
  hl("NotifyERRORIcon", { fg = colors.error })
  hl("NotifyWARNIcon", { fg = colors.warning })
  hl("NotifyINFOIcon", { fg = colors.info })
  hl("NotifyDEBUGIcon", { fg = colors.gray })
  hl("NotifyTRACEIcon", { fg = colors.hint })
  hl("NotifyERRORTitle", { fg = colors.error })
  hl("NotifyWARNTitle", { fg = colors.warning })
  hl("NotifyINFOTitle", { fg = colors.info })
  hl("NotifyDEBUGTitle", { fg = colors.gray })
  hl("NotifyTRACETitle", { fg = colors.hint })

  -- Mini.indentscope
  hl("MiniIndentscopeSymbol", { fg = colors.gray })

  -- Dashboard / Alpha
  hl("DashboardHeader", { fg = colors.blue })
  hl("DashboardCenter", { fg = colors.green })
  hl("DashboardShortcut", { fg = colors.blue_bright })
  hl("DashboardFooter", { fg = colors.gray })

  -- Illuminate
  hl("IlluminatedWordText", { bg = colors.bg_highlight })
  hl("IlluminatedWordRead", { bg = colors.bg_highlight })
  hl("IlluminatedWordWrite", { bg = colors.bg_highlight })

  -- Indent blankline
  hl("IndentBlanklineChar", { fg = colors.gray_dark })
  hl("IndentBlanklineContextChar", { fg = colors.gray })
  hl("IblIndent", { fg = colors.gray_dark })
  hl("IblScope", { fg = colors.gray })

  -- Cmp
  hl("CmpItemAbbr", { fg = colors.fg })
  hl("CmpItemAbbrDeprecated", { fg = colors.gray, strikethrough = true })
  hl("CmpItemAbbrMatch", { fg = colors.green, bold = true })
  hl("CmpItemAbbrMatchFuzzy", { fg = colors.green, bold = true })
  hl("CmpItemKind", { fg = colors.blue })
  hl("CmpItemMenu", { fg = colors.gray })

  -- Navic
  hl("NavicText", { fg = colors.fg })
  hl("NavicSeparator", { fg = colors.gray })

  -- Noice
  hl("NoiceCmdlinePopupBorder", { fg = colors.gray })
  hl("NoiceCmdlineIcon", { fg = colors.blue })
end

-- Auto-setup when sourced as colorscheme
M.setup()

return M
