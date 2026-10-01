-- Angular CLI command palette. Prompts for a component name and runs
-- `npm run ng generate component <name>` via Snacks.terminal.
-- This is the feature behind the <leader>ap keymap.
--
-- Snacks must be loaded before this feature is enabled (handled in
-- lua/plugins/navigation.lua via the snacks.nvim package).

local angular_utils = require('angular-rename.utils')

local M = {}

---Build a path relative to src/app/ for `ng generate` commands.
---ng generate always resolves names relative to <project-root>/src/app/,
---so we figure out the relative path from there to the current directory.
---@param component_name string
---@return string|nil root, string|nil gen_path
local function get_relative_gen_path(component_name)
    local dir = vim.fn.expand('%:p:h')
    local root = angular_utils.find_angular_root(dir)
    if not root then
        vim.notify('Could not find Angular project root', vim.log.levels.ERROR)
        return nil, nil
    end
    local src_app = root .. '/src/app'
    -- Strip src/app prefix to get the relative directory
    if dir:sub(1, #src_app) == src_app then
        local rel = dir:sub(#src_app + 2) -- +2 to skip the trailing /
        if rel and rel ~= '' then
            return root, rel .. '/' .. component_name
        end
    end
    return root, component_name
end

local commands = {
    {
        name = 'Generate Component (relative)',
        cmd = function()
            vim.ui.input({ prompt = 'Component name: ' }, function(name)
                if not name or name == '' then return end
                local root, gen_path = get_relative_gen_path(name)
                if not root then return end
                Snacks.terminal('npm run ng generate component ' .. gen_path, { cwd = root })
            end)
        end,
    },
    {
        name = 'Generate Component (absolute)',
        cmd = function()
            vim.ui.input({ prompt = 'Component name: ' }, function(name)
                if not name or name == '' then return end
                Snacks.terminal('npm run ng generate component ' .. name)
            end)
        end,
    },
}

function M.setup(cfg)
    cfg = cfg or {}
    local keymap = cfg.keymap or '<leader>ap'
    vim.keymap.set('n', keymap, function()
        local names = vim.tbl_map(function(c) return c.name end, commands)
        vim.ui.select(names, { prompt = 'Angular Commands' }, function(choice)
            if not choice then return end
            for _, c in ipairs(commands) do
                if c.name == choice then
                    c.cmd()
                    return
                end
            end
        end)
    end, { desc = '[A]ngular: Command [P]alette' })
end

return M
