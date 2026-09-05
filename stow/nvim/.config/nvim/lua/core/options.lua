
-- Neovim options configuration
-- Set leader key
vim.g.mapleader = " "

local opts = vim.o

-- TODO Sort and categorize these better?
opts.termguicolors = true -- enable 24-bit color
opts.tabstop = 4
opts.shiftwidth = 4
opts.expandtab = true -- Tab uses the correct space
opts.smartindent = true -- Indent correctly after a {
opts.autoindent = true
opts.scrolloff = 8  -- Lines to keep above and below cursor when scrolling down
opts.wrap = true -- Wrap when line becomes longer that the screen width
opts.breakindent = true -- Wrapped line gets the same indenting as the line it orignates from for better readability
opts.linebreak = true
opts.number = true
opts.cursorline = true
opts.signcolumn = "yes" -- Always show the sign column so we do not have jumping when disagnostics come in
opts.undofile = true
opts.ignorecase = true
opts.smartcase = true
opts.incsearch = true
opts.showmode = false -- Don't show mode in command line (statusline already shows it)
opts.cmdheight = 0 -- Hide command line when not in use
opts.winborder = "single" -- Default window border for all
vim.opt.shortmess:append("W") -- Should surpress write message in command line

-- Folding: managed by nvim-ufo (see plugins/editor.lua)
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

opts.fixendofline = true -- Always ensure a final newline on save

vim.g.editorconfig = true

-- LSP inlay hints (show inferred types, parameter names, etc.)
vim.lsp.inlay_hint.enable(true)

return {}
