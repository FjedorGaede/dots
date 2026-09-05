-- LSP configuration

-- Install LSP plugins
addPackage("neovim/nvim-lspconfig", "mason-org/mason.nvim", "mason-org/mason-lspconfig.nvim")

-- Install incremental rename
addPackage("smjonas/inc-rename.nvim")

-- Install LSP signature
addPackage("ray-x/lsp_signature.nvim")

-- Configure Mason
require("mason").setup()
require("mason-lspconfig").setup({
    -- automatic_enable defaults to true in mason-lspconfig, which would
    -- enable *every* installed Mason LSP (including `ts_ls` and `angularls`).
    -- We want to be explicit, so disable the auto-enable and pick the list
    -- ourselves below.
    automatic_enable = false,
    ensure_installed = {
        "lua_ls",
        "stylua",
        "vtsls",
        "ansiblels",  -- Added for Ansible LSP support
        "yamlls",     -- Added for YAML LSP support
        "bashls",
    }
})

-- Explicitly enable only the servers we want. `lsp/<name>.lua` configs
-- are picked up automatically by vim.lsp.enable.
vim.lsp.enable({
    "vtsls",     -- TypeScript / JavaScript
    "angularls", -- Angular templates (HTML only, see lsp/angularls.lua)
    "lua_ls",    -- Lua
    "qmlls",     -- QML
})

-- Configure incremental rename
require("inc_rename").setup {
    input_buffer_type = "snacks",
}

-- Configure LSP signature
-- TODO Do I really need this? Maybe I just want to always do it manually?
-- require("lsp_signature").setup({
--     hint_enable = true,
--     hint_prefix = "↖ ",
--     padding = " ",
--     handler_opts = {
--         border = "none"   -- double, rounded, single, shadow, none, or a table of borders
--     },
-- })

return {}
