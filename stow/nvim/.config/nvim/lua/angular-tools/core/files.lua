-- File resolution helpers shared by angular-tools features.
-- Currently: strip a known Angular extension to get the base path,
-- so features can compute sibling files (.ts, .html, .scss, etc.).

local M = {}

-- Known Angular file extensions, ordered from most to least specific so the
-- first match wins (e.g. foo.component.stories.ts is matched before .ts).
local known_exts = {
    '%.component%.stories%.ts',
    '%.component%.spec%.ts',
    '%.component%.ts',
    '%.component%.html',
    '%.component%.scss',
    '%.component%.css',
}

---Strip a known Angular extension from an absolute file path to get the base
---path. Returns nil if the file is not an Angular file.
---@param file string  absolute file path
---@return string|nil
function M.get_base(file)
    for _, ext in ipairs(known_exts) do
        local base = file:match('^(.-)' .. ext .. '$')
        if base then return base end
    end
end

return M
