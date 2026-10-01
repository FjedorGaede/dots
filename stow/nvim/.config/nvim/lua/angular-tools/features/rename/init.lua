-- Angular component rename via the vendored angular-rename module.
-- This is the feature behind the <leader>ar keymap.
--
-- The vendored module lives in lua/angular-rename/ (not a vim.pack package).
-- It depends on nui.nvim (loaded transitively when angular-rename is required).

local M = {}

function M.setup(cfg)
    cfg = cfg or {}
    require('angular-rename').setup({
        log_level = cfg.log_level or 'debug',  -- 'info' once you're comfortable with it
    })

    local keymap = cfg.keymap or '<leader>ar'
    vim.keymap.set('n', keymap, function()
        require('angular-rename').rename()
    end, { desc = '[A]ngular: [R]ename Component' })
end

return M
