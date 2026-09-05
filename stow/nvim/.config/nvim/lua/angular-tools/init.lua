-- angular-tools: a small collection of plugins that make Angular work in nvim
-- nicer. Features are toggled independently via setup({features = {...}}).
--
-- See docs/angular-tools.md (TODO) for the design.

local M = {}

local defaults = require('angular-tools.config')

---Load a single feature module and call its setup() with the merged config.
---@param name string  feature name, also the require path segment
---@param cfg table    feature config (may have {enabled, ...feature-specific})
local function load_feature(name, cfg)
    local ok, mod = pcall(require, 'angular-tools.features.' .. name)
    if not ok then
        vim.notify('angular-tools: unknown feature ' .. name, vim.log.levels.WARN)
        return
    end
    if cfg.enabled ~= false and type(mod.setup) == 'function' then
        mod.setup(cfg)
    end
end

---Initialize angular-tools. Called once from the nvim config.
---@param user_config table|nil  overrides for the default config
function M.setup(user_config)
    local cfg = vim.tbl_deep_extend('force', defaults, user_config or {})
    for name, feature_cfg in pairs(cfg.features) do
        load_feature(name, feature_cfg)
    end
end

return M
