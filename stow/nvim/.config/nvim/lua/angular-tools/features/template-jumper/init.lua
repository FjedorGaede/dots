-- Jump between sibling Angular files (.ts, .html, .scss, .stories.ts).
-- This is the feature behind the <leader>a{t,h,s,o} keymaps.

local files = require('angular-tools.core.files')

local M = {}

local function jump(file_type)
    local file = vim.fn.expand('%:p')
    local base = files.get_base(file)
    if not base then
        vim.notify('Not an Angular file', vim.log.levels.WARN)
        return
    end

    local suffix = file_type == 'stories'
        and '.component.stories.ts'
        or ('.component.' .. file_type)
    local target = base .. suffix

    if target == file then
        return
    elseif vim.fn.filereadable(target) == 1 then
        vim.cmd.edit(target)
    else
        vim.notify('No ' .. vim.fn.fnamemodify(target, ':t') .. ' found', vim.log.levels.WARN)
    end
end

function M.setup(cfg)
    cfg = cfg or {}
    local km = cfg.keymaps or {
        ts      = '<leader>at',
        html    = '<leader>ah',
        scss    = '<leader>as',
        stories = '<leader>ao',
    }

    local function map(keys, file_type, desc)
        vim.keymap.set('n', keys, function() jump(file_type) end, { desc = desc })
    end
    map(km.ts,      'ts',      '[A]ngular: jump to [T]ypeScript')
    map(km.html,    'html',    '[A]ngular: jump to [H]TML')
    map(km.scss,    'scss',    '[A]ngular: jump to [S]CSS')
    map(km.stories, 'stories', '[A]ngular: jump to St[o]ries')
end

return M
