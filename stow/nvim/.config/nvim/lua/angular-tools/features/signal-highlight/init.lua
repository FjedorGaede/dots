-- signal-highlight: WebStorm-style Angular signal highlighting.
-- Layer 1 (treesitter) + Layer 2 (LSP hover) cooperating paints.
-- See docs/angular-signal-highlighting.md for design.

local config     = require('angular-tools.features.signal-highlight.config')
local treesitter = require('angular-tools.features.signal-highlight.treesitter')
local lsp        = require('angular-tools.features.signal-highlight.lsp')
local files      = require('angular-tools.core.files')

local M = {}

local state = { enabled = true }

-- Default highlight look. Users can override at any time with
-- nvim_set_hl(0, '@angular.signal', {...}) — default = true ensures
-- later sets win.
vim.api.nvim_set_hl(0, config.HL_GROUP, config.HL_DEFAULT)

-- ## Cycle coordination ## --

---Run one cycle for `buf`: Layer 1 paints synchronously, Layer 2
---verifications start asynchronously. A single redraw (clear + emit
---verified set) fires after the burst of verifications settles.
local function full_scan_ts(buf)
    local ts_state = treesitter.build_ts_state(buf)
    if not ts_state then return end
    lsp.start_cycle(buf)
    local l2_candidates = treesitter.paint_ts_state(ts_state, function(range)
        lsp.note_l1_paint(buf, range)
    end)
    lsp.lsp_scan_ts(ts_state, l2_candidates)
end

local function full_scan_html(buf)
    local html_state = treesitter.build_html_state(buf)
    if not html_state then return end
    lsp.start_cycle(buf)
    treesitter.paint_html_state(html_state, function(range)
        lsp.note_l1_paint(buf, range)
    end)
    lsp.lsp_scan_html(html_state)
end

-- ## Autocmd setup ## --

local group = vim.api.nvim_create_augroup('AngularSignalHighlight', { clear = true })

local function debounced(buf, fn)
    local timer = nil
    return function()
        if timer then timer:stop() end
        timer = vim.defer_fn(function()
            timer = nil
            if vim.api.nvim_buf_is_valid(buf) then
                fn(buf)
            end
        end, config.DEBOUNCE_MS)
    end
end

local function on_filetype(pattern, scan_fn)
    vim.api.nvim_create_autocmd('FileType', {
        group = group,
        pattern = pattern,
        callback = function(args)
            local buf = args.buf
            -- defer initial scan so treesitter / injections are set up
            vim.schedule(function()
                if state.enabled and vim.api.nvim_buf_is_valid(buf) then scan_fn(buf) end
            end)
            vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
                group = group,
                buffer = buf,
                callback = debounced(buf, function(b)
                    if state.enabled then scan_fn(b) end
                end),
            })
        end,
    })
end

-- ## Public API ## --

---Initialize signal-highlight. Called by angular-tools.setup() when the
---feature is enabled. Sets up the highlight, autocmds, and user command.
---@param user_config table|nil  {hl = table}  -- override the highlight look
function M.setup(user_config)
    user_config = user_config or {}
    if user_config.hl then
        local hl = vim.tbl_extend('force', { default = true }, user_config.hl)
        vim.api.nvim_set_hl(0, config.HL_GROUP, hl)
    end

    on_filetype('typescript', full_scan_ts)
    on_filetype('htmlangular', full_scan_html)

    -- Re-scan open html templates when their component .ts is written.
    -- Only fires for .component.ts (the only .ts that has a .html sibling);
    -- uses the shared core/files helper for the path resolution.
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = '*.ts',
        callback = function(args)
            if not state.enabled then return end
            if not args.file:match('%.component%.ts$') then return end
            local base = files.get_base(args.file)
            if not base then return end
            local html_path = base .. '.component.html'
            local html_buf = vim.fn.bufnr(html_path)
            if html_buf ~= -1 and vim.api.nvim_buf_is_loaded(html_buf) then
                full_scan_html(html_buf)
            end
        end,
    })

    -- Layer 2 needs LSP: rescan once a relevant client attaches.
    vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(args)
            local buf = args.buf
            local ft = vim.bo[buf].filetype
            if ft == 'typescript' then
                vim.defer_fn(function()
                    if state.enabled and vim.api.nvim_buf_is_valid(buf) then
                        local ts_state = treesitter.build_ts_state(buf)
                        if ts_state then
                            lsp.start_cycle(buf)
                            local l2 = treesitter.paint_ts_state(ts_state, function(range)
                                lsp.note_l1_paint(buf, range)
                            end)
                            lsp.lsp_scan_ts(ts_state, l2)
                        end
                    end
                end, config.LSP_ATTACH_DELAY_MS)
            elseif ft == 'htmlangular' then
                vim.defer_fn(function()
                    if state.enabled and vim.api.nvim_buf_is_valid(buf) then
                        local html_state = treesitter.build_html_state(buf)
                        if html_state then
                            lsp.start_cycle(buf)
                            lsp.lsp_scan_html(html_state)
                        end
                    end
                end, config.LSP_ATTACH_DELAY_MS)
            end
        end,
    })

    -- Types may change on save: drop cache entries whose symbols are
    -- defined in the saved file. Other buffers' caches stay valid.
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = '*.ts',
        callback = function(args)
            lsp.invalidate_file(args.file)
        end,
    })

    vim.api.nvim_create_autocmd('BufDelete', {
        group = group,
        callback = function(args)
            lsp.invalidate_buffer(args.buf)
        end,
    })
end

-- ## User command ## --

local function scan_buffer(buf)
    local ft = vim.bo[buf].filetype
    if ft == 'typescript' then
        full_scan_ts(buf)
    elseif ft == 'htmlangular' then
        full_scan_html(buf)
    end
end

local function clear_all()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            vim.api.nvim_buf_clear_namespace(buf, config.NS, 0, -1)
        end
    end
end

local function scan_all()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            scan_buffer(buf)
        end
    end
end

local subcommands = {
    on = function()
        state.enabled = true
        scan_all()
    end,
    off = function()
        state.enabled = false
        clear_all()
    end,
    toggle = function()
        if state.enabled then subcommands.off() else subcommands.on() end
        vim.notify('Signal highlight: ' .. (state.enabled and 'on' or 'off'))
    end,
    refresh = function()
        lsp.invalidate_all()
        scan_all()
    end,
}

vim.api.nvim_create_user_command('SignalHighlight', function(opts)
    local sub = opts.args ~= '' and opts.args or 'toggle'
    local fn = subcommands[sub]
    if not fn then
        vim.notify('SignalHighlight: unknown subcommand ' .. sub, vim.log.levels.ERROR)
        return
    end
    fn()
end, {
    nargs = '?',
    complete = function() return vim.tbl_keys(subcommands) end,
    desc = 'Toggle Angular signal highlighting (on|off|toggle|refresh)',
})

-- Public functions for manual triggering / tests.
M.scan      = full_scan_ts
M.scan_html = full_scan_html

return M
