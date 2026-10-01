-- Color scheme and custom highlights
 -- TODO CLEAN THIS FUCKING THING UP!!!!
-- Install color scheme
addPackage("Mofiqul/dracula.nvim")

-- Configure Dracula color scheme
require('dracula').setup({})

vim.cmd.colorscheme("dracula")

-- Custom highlights for floating windows
-- Define a unified color scheme for all floats (LSP hover, diagnostics, completion, signature, git hunks)
local colors = require("dracula").colors()
local hightlightColor = "#F6AEDE"
local satisfiyingPink = "#FC1E9D"
local darkerGreen = "#6BBF7A"
local satisfiyingBlue = "#4287F5"
local customCommentColor = "#7B8EC9"

local float_bg = colors.menu
local float_border_fg = colors.purple
local float_border_bg = colors.menu
local fg = colors.fg
local bg = colors.bg
local selection = colors.selection

---@param name string
---@param opts vim.api.keyset.highlight
local set_hl = function(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
end

-- Color the Float Windows
set_hl("NormalFloat", { bg = float_bg, fg = fg })
set_hl("FloatBorder", { bg = float_bg, fg = float_border_fg })

-- Diagnostic floating windows
set_hl("DiagnosticFloatNormal", { link = "NormalFloat" })
set_hl("DiagnosticFloatBorder", { link = "FloatBorder" })

-- Completion menu
set_hl("Pmenu", { bg = float_bg, fg = fg })
set_hl("PmenuSel", { bg = selection, fg = hightlightColor, bold = true })
set_hl("PmenuBorder", { bg = float_bg, fg = float_border_fg })
set_hl("BlinkCmpLabelMatch", { fg = "white", bold = true }) -- The other matches 

-- Signature 
set_hl("BlinkCmpSignatureHelpBorder", { bg = float_border_bg, fg = float_border_fg })
set_hl("BlinkCmpSignatureHelpActiveParameter", { bg = colors.bg, fg = colors.bright_blue }) -- If you want to change the color here at some point

-- Blink (if you want to style blink separately)
-- set_hl("BlinkCmpMenuSelection", { bg = colors.selection, fg = colors.bright_blue })
-- set_hl("BlinkCmpMenuBorder", { bg = float_border_bg, fg = float_border_fg }) -- this needs to have the same background otherwise the menu looks strange
-- set_hl("BlinkCmpDocBorder", { bg = float_border_bg, fg = float_border_fg }) -- this needs to have the same background otherwise the menu looks strange
-- set_hl("BlinkCmpDocSeparator", { bg = colors.bg, fg = colors.bright_blue }) -- this needs to have the same background otherwise the menu looks strange
-- set_hl("BlinkCmpMenu", { bg = colors.bg })
-- set_hl("BlinkCmpScrollBarThumb", { bg = colors.bright_blue })

-- LSP Signature
set_hl("LspSignatureActiveParameter", { bg = selection, fg = fg, bold = true })

-- Git hunk preview (if using gitsigns or similar)
set_hl("GitSignsPreviewInline", { link = "NormalFloat" })

-- Set OnYank highlight
-- Mini has something to offer for that maybe?
set_hl("OnYank", { bg = hightlightColor, fg = "black" })

-- Code
set_hl("Comment", { fg = customCommentColor })

-- Color Panel

-- Git Signs
set_hl("MiniDiffSignAdd", { bg = colors.bg, fg = darkerGreen, bold = true })
set_hl("MiniDiffSignChange", { bg = colors.bg, fg = satisfiyingBlue, bold = true })
set_hl("MiniDiffSignDelete", { bg = colors.bg, fg = colors.red, bold = true })
set_hl("MiniDiffOverAdd", { bg = colors.green, fg = colors.red })
set_hl("MiniDiffOverChange", { bg = colors.green, fg = colors.red })
set_hl("MiniDiffOverChangeBuf", { bg = colors.green, fg = colors.red })
set_hl("MiniDiffOverContext", { bg = colors.green, fg = colors.red })
set_hl("MiniDiffOverContextBuf", { bg = colors.green, fg = colors.red })
set_hl("MiniDiffOverDelete", { bg = colors.green, fg = colors.red })

-- Snacks --
set_hl("SnacksIndentChunk", { fg = "#53576D" })
set_hl("SnacksIndentScope", { fg = "#53576D" })
set_hl("SnacksZenIcon", { fg = satisfiyingPink })

-- Snacks.picker --
set_hl("Title", { fg = hightlightColor, bold = true })
set_hl("SnacksPickerDir", { fg = customCommentColor })
set_hl("SnacksPickerBorder", { fg = float_border_fg, bg = float_border_bg })
set_hl("SnacksPickerToggle", { fg = hightlightColor, italic = true })
set_hl("SnacksPickerTitle", { fg = hightlightColor, bold = true })
set_hl("SnacksPickerMatch", {
  bg = satisfiyingPink,
  fg = colors.bright_white,
})

-- Flash
set_hl("FlashMatch", { fg = colors.black, bg = colors.purple, bold = true })
set_hl("FlashCurrent", { fg = colors.black, bg = colors.orange, bold = true })
set_hl("FlashLabel", { fg = colors.black, bg = colors.pink, bold = true })
set_hl("FlashBackdrop", {}) -- We currently do not set any

-- MINI --

-- Mini Hipatterns --
set_hl("MiniHipatternsFixme", { bg = colors.bright_red, fg = colors.bg, bold = true }) -- FIXME
set_hl("MiniHipatternsHack", { bg = colors.orange, fg = colors.bg, bold = true }) -- HACK
set_hl("MiniHipatternsTodo", { bg = colors.pink, fg = colors.bg, bold = true }) -- TODO
set_hl("MiniHipatternsNote", { bg = colors.bright_blue, fg = colors.bg, bold = true }) -- NOTE

-- Mini statusline
set_hl("MiniStatuslineModeNormal", { fg = colors.black, bg = colors.bright_white })
set_hl("MiniStatuslineModeInsert", { fg = colors.black, bg = colors.purple })
set_hl("MiniStatuslineModeVisual", { fg = colors.black, bg = colors.green })
set_hl("MiniStatuslineFilename", { fg = colors.bright_white, bg = colors.visual, bold = false })
set_hl("MiniStatuslineModifiedIndicator", { fg = colors.visual, bg = colors.pink })
set_hl("MiniStatuslineFileinfo", { fg = colors.white, bg = colors.black })
set_hl("MiniStatuslineDevinfo", { fg = colors.white, bg = colors.black })
set_hl("MiniStatuslineDiagnostics", { fg = colors.black, bg = colors.orange })
set_hl("MiniStatuslineMacro", { fg = colors.black, bg = colors.pink, bold = true })

-- This can be used for making it easier to see inactive split window
set_hl("MiniStatuslineInactive", { fg = colors.white, bg = colors.visual, italic = true })

-- Mini files
set_hl("MiniFilesBorder", { fg = float_border_fg, bg = float_border_bg })
set_hl("MiniFilesBorderModified", { fg = colors.orange, bg = float_border_bg })
set_hl("MiniFilesCursorLine", { bg = colors.selection })
set_hl("MiniFilesDirectory", { fg = colors.purple })
set_hl("MiniFilesFile", { fg = colors.bright_white })
set_hl("MiniFilesNormal", {})
set_hl("MiniFilesTitle", { fg = colors.bright_white })
set_hl("MiniFilesTitleFocused", { fg = colors.bright_red, bold = true })

return {}
