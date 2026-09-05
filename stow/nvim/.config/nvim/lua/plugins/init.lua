-- Plugin manager and configuration loader

-- Define the add function for managing plugins
local M = {}

function M.addPackage(...)
    local githubPrefix = "git@github.com:"
    local plugins = { ... }
    local sources = {}
    for _, plugin in ipairs(plugins) do
        local to_insert = nil

        if type(plugin) == "string" then
            to_insert = { src = githubPrefix .. plugin }
        elseif type(plugin) == "table" then
            to_insert = vim.deepcopy(plugin)
            to_insert.src = githubPrefix .. plugin.src
        end

        table.insert(sources, to_insert)
    end

    vim.pack.add(sources)
end

-- Make addPackage available globally for plugin modules
_G.addPackage = M.addPackage

-- Load all plugin configurations
-- Each module will call addPackage() and configure its plugins
require("plugins.lsp")
require("plugins.completion")
require("plugins.ui")
require("plugins.editor")
require("plugins.navigation")
require("plugins.git")

return M
