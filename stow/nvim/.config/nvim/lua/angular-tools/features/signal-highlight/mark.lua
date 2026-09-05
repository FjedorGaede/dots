-- Extmark helpers. Both layers paint into the same namespace (config.NS);
-- the namespace was unified in pass 2.1 (see docs/signal-highlight-refactor.md).

local config = require('angular-tools.features.signal-highlight.config')

local M = {}

---Paint a single extmark in the signal-highlight namespace.
---@param buf integer
---@param range number[]  {start_row, start_col, end_row, end_col}
function M.place(buf, range)
    vim.api.nvim_buf_set_extmark(buf, config.NS, range[1], range[2], {
        end_row = range[3],
        end_col = range[4],
        hl_group = config.HL_GROUP,
        priority = config.PRIORITY,
    })
end

return M
