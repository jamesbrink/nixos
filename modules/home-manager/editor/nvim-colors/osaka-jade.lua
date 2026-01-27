-- Osaka Jade colorscheme for Neovim
-- Custom colorscheme matching our theme system colors

local M = {}

-- Color palette from modules/themes/definitions/osaka-jade.nix
local colors = {
  bg = "#111c18",
  bg_dark = "#0a1410",
  bg_light = "#1a2a24",
  bg_highlight = "#23372B",

  fg = "#C1C497",
  fg_dark = "#9a9a72",
  fg_light = "#F6F5DD",
  fg_bright = "#F7E8B2",

  black = "#23372B",
  red = "#FF5345",
  red_dark = "#db9f9c",
  green = "#549e6a",
  green_light = "#63b07a",
  green_dark = "#143614",
  yellow = "#E5C736",
  yellow_dark = "#459451",
  blue = "#509475", -- jade green
  blue_light = "#ACD4CF",
  magenta = "#D2689C",
  magenta_light = "#75bbb3",
  cyan = "#2DD5B7",
  cyan_light = "#8CD3CB",
  white = "#F6F5DD",
  white_bright = "#9eebb3",

  gray = "#53685B",
  gray_dark = "#32473B",

  -- Accent (jade/mint)
  accent = "#71CEAD",
  accent_light = "#81B8A8",

  -- Semantic colors
  error = "#FF5345",
  warning = "#E5C736",
  info = "#2DD5B7",
  hint = "#53685B",
  success = "#549e6a",

  -- Git colors
  git_add = "#549e6a",
  git_change = "#E5C736",
  git_delete = "#FF5345",

  -- Selection
  selection = "#23372B",
  cursor = "#D7C995",
}

function M.setup()
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true
  vim.g.colors_name = "osaka-jade"

  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Editor UI
  hl("Normal", { fg = colors.fg, bg = colors.bg })
  hl("NormalNC", { fg = colors.fg, bg = colors.bg })
  hl("NormalFloat", { fg = colors.fg, bg = colors.bg_light })
  hl("FloatBorder", { fg = colors.accent, bg = colors.bg_light })
  hl("FloatTitle", { fg = colors.accent, bg = colors.bg_light, bold = true })
  hl("Cursor", { fg = colors.bg, bg = colors.cursor })
  hl("CursorLine", { bg = colors.bg_highlight })
  hl("CursorColumn", { bg = colors.bg_highlight })
  hl("ColorColumn", { bg = colors.bg_light })
  hl("LineNr", { fg = colors.gray_dark })
  hl("CursorLineNr", { fg = colors.accent, bold = true })
  hl("SignColumn", { fg = colors.gray, bg = colors.bg })
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
  hl("PmenuSel", { fg = colors.bg, bg = colors.accent })
  hl("PmenuSbar", { bg = colors.bg_light })
  hl("PmenuThumb", { bg = colors.accent })

  -- Search & Visual
  hl("Search", { fg = colors.bg, bg = colors.yellow })
  hl("IncSearch", { fg = colors.bg, bg = colors.accent })
  hl("CurSearch", { fg = colors.bg, bg = colors.accent })
  hl("Substitute", { fg = colors.bg, bg = colors.red })
  hl("Visual", { bg = colors.selection })
  hl("VisualNOS", { bg = colors.selection })

  -- Messages
  hl("ModeMsg", { fg = colors.accent, bold = true })
  hl("MsgArea", { fg = colors.fg })
  hl("MoreMsg", { fg = colors.cyan })
  hl("Question", { fg = colors.cyan })
  hl("ErrorMsg", { fg = colors.error })
  hl("WarningMsg", { fg = colors.warning })

  -- Statusline & Tabline
  hl("StatusLine", { fg = colors.fg, bg = colors.bg_light })
  hl("StatusLineNC", { fg = colors.gray, bg = colors.bg_dark })
  hl("TabLine", { fg = colors.gray, bg = colors.bg_dark })
  hl("TabLineFill", { bg = colors.bg_dark })
  hl("TabLineSel", { fg = colors.accent, bg = colors.bg })
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
  hl("Constant", { fg = colors.cyan })
  hl("String", { fg = colors.green })
  hl("Character", { fg = colors.green })
  hl("Number", { fg = colors.cyan })
  hl("Boolean", { fg = colors.cyan })
  hl("Float", { fg = colors.cyan })

  hl("Identifier", { fg = colors.fg })
  hl("Function", { fg = colors.accent })

  hl("Statement", { fg = colors.magenta })
  hl("Conditional", { fg = colors.magenta })
  hl("Repeat", { fg = colors.magenta })
  hl("Label", { fg = colors.magenta })
  hl("Operator", { fg = colors.fg_light })
  hl("Keyword", { fg = colors.magenta })
  hl("Exception", { fg = colors.red })

  hl("PreProc", { fg = colors.cyan })
  hl("Include", { fg = colors.magenta })
  hl("Define", { fg = colors.magenta })
  hl("Macro", { fg = colors.cyan })
  hl("PreCondit", { fg = colors.magenta })

  hl("Type", { fg = colors.yellow })
  hl("StorageClass", { fg = colors.magenta })
  hl("Structure", { fg = colors.yellow })
  hl("Typedef", { fg = colors.yellow })

  hl("Special", { fg = colors.cyan })
  hl("SpecialChar", { fg = colors.cyan_light })
  hl("Tag", { fg = colors.accent })
  hl("Delimiter", { fg = colors.fg })
  hl("SpecialComment", { fg = colors.gray })
  hl("Debug", { fg = colors.warning })

  hl("Underlined", { fg = colors.cyan, underline = true })
  hl("Bold", { bold = true })
  hl("Italic", { italic = true })

  hl("Ignore", { fg = colors.gray_dark })
  hl("Error", { fg = colors.error })
  hl("Todo", { fg = colors.bg, bg = colors.accent, bold = true })

  -- Treesitter
  hl("@comment", { link = "Comment" })
  hl("@punctuation", { fg = colors.fg })
  hl("@punctuation.bracket", { fg = colors.fg })
  hl("@punctuation.delimiter", { fg = colors.fg })
  hl("@punctuation.special", { fg = colors.cyan })

  hl("@constant", { link = "Constant" })
  hl("@constant.builtin", { fg = colors.cyan })
  hl("@constant.macro", { link = "Macro" })

  hl("@string", { link = "String" })
  hl("@string.regex", { fg = colors.cyan_light })
  hl("@string.escape", { fg = colors.cyan })
  hl("@string.special", { fg = colors.cyan_light })

  hl("@character", { link = "Character" })
  hl("@number", { link = "Number" })
  hl("@boolean", { link = "Boolean" })
  hl("@float", { link = "Float" })

  hl("@function", { link = "Function" })
  hl("@function.builtin", { fg = colors.accent })
  hl("@function.macro", { link = "Macro" })
  hl("@function.call", { fg = colors.accent })

  hl("@method", { fg = colors.accent })
  hl("@method.call", { fg = colors.accent })

  hl("@constructor", { fg = colors.yellow })
  hl("@parameter", { fg = colors.fg, italic = true })

  hl("@keyword", { link = "Keyword" })
  hl("@keyword.function", { fg = colors.magenta })
  hl("@keyword.operator", { fg = colors.magenta })
  hl("@keyword.return", { fg = colors.magenta })

  hl("@conditional", { link = "Conditional" })
  hl("@repeat", { link = "Repeat" })
  hl("@label", { link = "Label" })
  hl("@operator", { link = "Operator" })
  hl("@exception", { link = "Exception" })

  hl("@variable", { fg = colors.fg })
  hl("@variable.builtin", { fg = colors.red })

  hl("@type", { link = "Type" })
  hl("@type.builtin", { fg = colors.yellow })
  hl("@type.definition", { link = "Type" })
  hl("@type.qualifier", { fg = colors.magenta })

  hl("@namespace", { fg = colors.fg })
  hl("@include", { link = "Include" })

  hl("@attribute", { fg = colors.cyan })
  hl("@property", { fg = colors.fg })
  hl("@field", { fg = colors.fg })

  hl("@tag", { fg = colors.accent })
  hl("@tag.attribute", { fg = colors.yellow })
  hl("@tag.delimiter", { fg = colors.fg })

  hl("@text", { fg = colors.fg })
  hl("@text.strong", { bold = true })
  hl("@text.emphasis", { italic = true })
  hl("@text.underline", { underline = true })
  hl("@text.strike", { strikethrough = true })
  hl("@text.title", { fg = colors.accent, bold = true })
  hl("@text.literal", { fg = colors.green })
  hl("@text.uri", { fg = colors.cyan, underline = true })
  hl("@text.reference", { fg = colors.cyan })
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
  hl("DiagnosticVirtualTextError", { fg = colors.error, bg = "#1f1a1a" })
  hl("DiagnosticVirtualTextWarn", { fg = colors.warning, bg = "#1f1f1a" })
  hl("DiagnosticVirtualTextInfo", { fg = colors.info, bg = "#1a1f1f" })
  hl("DiagnosticVirtualTextHint", { fg = colors.hint, bg = "#1a1a1a" })

  -- Git signs
  hl("GitSignsAdd", { fg = colors.git_add })
  hl("GitSignsChange", { fg = colors.git_change })
  hl("GitSignsDelete", { fg = colors.git_delete })

  -- Telescope
  hl("TelescopeNormal", { fg = colors.fg, bg = colors.bg })
  hl("TelescopeBorder", { fg = colors.accent, bg = colors.bg })
  hl("TelescopePromptNormal", { fg = colors.fg, bg = colors.bg_light })
  hl("TelescopePromptBorder", { fg = colors.accent, bg = colors.bg_light })
  hl("TelescopePromptTitle", { fg = colors.bg, bg = colors.accent })
  hl("TelescopePreviewTitle", { fg = colors.bg, bg = colors.green })
  hl("TelescopeResultsTitle", { fg = colors.bg, bg = colors.magenta })
  hl("TelescopeSelection", { bg = colors.bg_highlight })
  hl("TelescopeSelectionCaret", { fg = colors.accent })
  hl("TelescopeMatching", { fg = colors.yellow, bold = true })

  -- Neo-tree
  hl("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeDirectoryName", { fg = colors.accent })
  hl("NeoTreeDirectoryIcon", { fg = colors.accent })
  hl("NeoTreeRootName", { fg = colors.accent, bold = true })
  hl("NeoTreeFileName", { fg = colors.fg })
  hl("NeoTreeFileIcon", { fg = colors.fg })
  hl("NeoTreeGitAdded", { fg = colors.git_add })
  hl("NeoTreeGitModified", { fg = colors.git_change })
  hl("NeoTreeGitDeleted", { fg = colors.git_delete })
  hl("NeoTreeGitUntracked", { fg = colors.gray })
  hl("NeoTreeIndentMarker", { fg = colors.gray_dark })

  -- Which-key
  hl("WhichKey", { fg = colors.accent })
  hl("WhichKeyGroup", { fg = colors.cyan })
  hl("WhichKeyDesc", { fg = colors.fg })
  hl("WhichKeySeparator", { fg = colors.gray })
  hl("WhichKeyFloat", { bg = colors.bg_light })

  -- Lazy.nvim
  hl("LazyH1", { fg = colors.bg, bg = colors.accent, bold = true })
  hl("LazyButton", { fg = colors.fg, bg = colors.bg_light })
  hl("LazyButtonActive", { fg = colors.bg, bg = colors.accent })
  hl("LazySpecial", { fg = colors.cyan })

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
  hl("MiniIndentscopeSymbol", { fg = colors.accent })

  -- Dashboard / Alpha
  hl("DashboardHeader", { fg = colors.accent })
  hl("DashboardCenter", { fg = colors.cyan })
  hl("DashboardShortcut", { fg = colors.yellow })
  hl("DashboardFooter", { fg = colors.gray })

  -- Illuminate
  hl("IlluminatedWordText", { bg = colors.bg_highlight })
  hl("IlluminatedWordRead", { bg = colors.bg_highlight })
  hl("IlluminatedWordWrite", { bg = colors.bg_highlight })

  -- Indent blankline
  hl("IndentBlanklineChar", { fg = colors.gray_dark })
  hl("IndentBlanklineContextChar", { fg = colors.accent })
  hl("IblIndent", { fg = colors.gray_dark })
  hl("IblScope", { fg = colors.accent })

  -- Cmp
  hl("CmpItemAbbr", { fg = colors.fg })
  hl("CmpItemAbbrDeprecated", { fg = colors.gray, strikethrough = true })
  hl("CmpItemAbbrMatch", { fg = colors.accent, bold = true })
  hl("CmpItemAbbrMatchFuzzy", { fg = colors.accent, bold = true })
  hl("CmpItemKind", { fg = colors.cyan })
  hl("CmpItemMenu", { fg = colors.gray })

  -- Navic
  hl("NavicText", { fg = colors.fg })
  hl("NavicSeparator", { fg = colors.gray })

  -- Noice
  hl("NoiceCmdlinePopupBorder", { fg = colors.accent })
  hl("NoiceCmdlineIcon", { fg = colors.accent })
end

-- Auto-setup when sourced as colorscheme
M.setup()

return M
