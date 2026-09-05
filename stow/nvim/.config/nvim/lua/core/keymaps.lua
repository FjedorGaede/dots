-- Key mappings configuration

local keymap = vim.keymap.set

local function nmap(keys, callback, desc)
    keymap("n", keys, callback, { desc = desc })
end

local function xmap(keys, callback, desc)
    keymap("x", keys, callback, { desc = desc })
end

-- Flash jump
nmap("<CR>", function() require("flash").jump() end, "Flash-Jump")

-- Map m to forward and , to backward to have quicker access for moving to things
nmap("m", "]")
nmap(",", "[")

-- Make the down and up feel more deterministic
nmap("<C-d>", "8j")
nmap("<C-u>", "8k")

-- System clipboard
nmap("<leader>p", '"+p', "Paste from system clipboard")
nmap("<leader>y", '"+yy', "Copy line to clipboard")
xmap("<leader>y", '"+y', "Copy visual selection to clipboard")

-- Reload the nvim configuration
nmap("<leader>r", ":source $MYVIMRC <CR>")

-- "E"xplore files
nmap("<leader>ee", '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', 'Open on current file' )
nmap("<leader>ed", '<Cmd>lua MiniFiles.open()<CR>', 'Open at directory')

-- Fuzzy file search
nmap("<leader>ff", function() Snacks.picker.files({ live = false, hidden = true }) end, "[F]ind [F]iles")
nmap("<leader>fs", function() Snacks.picker.grep({ live = true, hidden = true }) end, "[F]ind [S]tring in Files")
nmap("<leader>fr", function() Snacks.picker.recent({ filter = { cwd = true } }) end, "[F]ind [R]ecent Files")
nmap("<leader>fl", function() Snacks.picker.resume() end, "[F]ocus [L]ast Picker")
nmap("<leader>fe", function() Snacks.picker.explorer() end, "[F]uzzy [E]xplorer")
nmap("<leader>fh", function() Snacks.picker.help() end, "[F]ind [H]elp")
nmap("<leader>fx", function() Snacks.picker.command_history() end, "[F]ind [X]ommands")
nmap("<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, "[F]ind [C]onfig")
nmap("<leader>hl", function() Snacks.picker.files({ cwd = "~/.config/hypr"}) end, "[H]yper[l]and Configuration")

-- Git
nmap("<leader>gl", function() Snacks.lazygit.open() end, "[H]yper[l]and Configuration")
nmap("<leader>gs", function() Snacks.lazygit.log_file() end, "[H]yper[l]and Configuration")

-- LSP navigation
-- Cross-server dedup: when multiple LSPs are attached (e.g. vtsls +
-- angularls on .ts), each returns its own list of locations and many
-- entries overlap. The helpers in core.lsp fan out to all clients,
-- dedup by uri:line:col, and show the result in a single picker.
local lsp_nav = function() return require("core.lsp") end

-- gd: Angular component selector (via @Component decorator) gets
-- cross-language jump to template usages. Otherwise fall through to
-- the LSP dedup path.
local function go_to_definition_or_references()
    local ok, selector_mod = pcall(require, "angular-tools.features.selector-usages")
    if ok then
        local hit = selector_mod.detect()
        if hit then
            selector_mod.find_usages(hit.selector)
            return
        end
    end
    lsp_nav().go_to_definition_or_references()
end

nmap("gr", function() lsp_nav().references() end, "[G]o to [R]eferences")
nmap("gd", go_to_definition_or_references, "[G]o to [D]efinition")
nmap("gi", function() lsp_nav().implementations() end, "[G]o to [I]mplementations")
keymap({ "n", "v" }, "<leader>ca", function() vim.lsp.buf.code_action() end, { desc = "[C]ode [A]ctions" })
keymap('n', '<leader>oi', function()
  vim.lsp.buf.code_action({
    apply = true,
    context = { only = { 'source.organizeImports' }, diagnostics = {} },
  })
end, { desc = '[O]rganize [I]mports' })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  callback = function(ev)
    vim.keymap.set('n', '<leader>mi', function()
      vim.lsp.buf.code_action({
        apply = true,
        context = { only = { 'source.addMissingImports' }, diagnostics = {} },
      })
    end, { buffer = ev.buf, desc = 'Add [M]issing [I]mports' })
  end,
})

-- Diagnostics & LSP
nmap("<leader>d", "<Cmd>lua vim.diagnostic.open_float()<CR>", "Show diagnostic hover")
nmap("md", "<Cmd>lua vim.diagnostic.jump({count=1, float=true})<CR>", "Jump to next diagnostic")
nmap(",d", "<Cmd>lua vim.diagnostic.jump({count=-1, float=true})<CR>", "Jump to previous diagnostic")
nmap("]d", "<Cmd>lua vim.diagnostic.jump({count=1, float=true})<CR>", "Jump to next diagnostic")

-- Incremental rename
vim.keymap.set("n", "R", function()
  return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true })

-- Toggle inlay hints
nmap("<leader>ti", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, "[T]oggle [I]nlay Hints")

-- Undotree --
vim.cmd("packadd nvim.undotree")
vim.keymap.set("n", "<leader>u", require("undotree").open)

return {}
