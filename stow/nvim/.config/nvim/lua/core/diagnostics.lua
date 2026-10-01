
-- LSP diagnostics configuration
local severity = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR }
vim.diagnostic.config({
    float = { source = 'if_many',  },

    -- Show signs on top of any other sign, but only for warnings and errors
    signs = { priority = 9999, severity = severity },

    -- Show all diagnostics as underline (for their messages type `<Leader>ld`)
    underline = { severity = severity },

    -- Show more details immediately for errors on the current line
    virtual_lines = false,
    virtual_text = {
        current_line = true,
        severity = severity,
    },

    -- Don't update diagnostics when typing
    update_in_insert = false,
})

return {}
