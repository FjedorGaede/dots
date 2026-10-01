-- Layer 2: async LSP hover verification.
-- Catches cross-file signals (e.g. `store.count` on an injected service)
-- and corrects Layer 1 false positives that hover can disprove.
--
-- Each cache entry remembers the file its symbol is defined in, so saving
-- a .ts file only invalidates entries whose definition lives in that file.
--
-- Pass 2 refactor: lsp_scan_{ts,html} now consumes a BufState from
-- treesitter.lua (no re-parse) and writes into the same NS as Layer 1
-- (NS_LSP was collapsed in 2.1). One redraw pass per cycle: clear once,
-- then emit (Layer 1 minus rejections) + Layer 2 verified.

local config  = require('angular-tools.features.signal-highlight.config')
local queries = require('angular-tools.features.signal-highlight.queries')
local mark    = require('angular-tools.features.signal-highlight.mark')
local treesitter = require('angular-tools.features.signal-highlight.treesitter')

local M = {}

-- Per-buffer cache. Each entry remembers the file its symbol is defined
-- in (from the LSP definition query) so per-file invalidation works.
--   hover_cache[buf][key] = { verdict = true|false, file = string }
--   nil entry  = not yet queried; next scan will re-query
--   verdict=false, file=nil  = pending (request in flight)
--   verdict=true|file=path  = resolved
local hover_cache = {}

-- Per-buffer active cycle. Set by init.lua's orchestrator before either
-- layer runs; both layers mutate it; the redraw debounce flushes it.
--   cycles[buf] = {
--     l1_painted   = set<range_key>,  ranges painted by Layer 1
--     l2_verified  = set<range_key>,  ranges confirmed by Layer 2
--     l2_rejected  = set<range_key>,  Layer 1 ranges disproved by Layer 2
--     timer        = uv_timer_t|nil,  debounce handle for the redraw
--     debounce     = integer,         ms remaining when this cycle started
--   }
local cycles = {}

-- ## LSP response helpers ## --

---Normalize LSP hover contents to a single string.
local function hover_text(contents)
    if type(contents) == 'string' then return contents end
    if type(contents) ~= 'table' then return '' end
    if contents.value then return contents.value end
    local parts = {}
    for _, c in ipairs(contents) do
        parts[#parts + 1] = type(c) == 'table' and (c.value or '') or tostring(c)
    end
    return table.concat(parts, '\n')
end

---Classify hover text: 'signal' | 'not_signal' | 'unknown'.
---Only `(property) Foo.bar: Type` lines count; the first colon after the
---property path decides. Methods (e.g. `hasValue(): this is ResourceRef<T>`)
---never count. 'unknown' means hover was inconclusive (e.g. angularls
---expands the Signal alias of computed() to `() => T`).
local function classify_hover(text)
    for line in text:gmatch('[^\n]+') do
        local rest = line:match('%(property%)%s*[%w_%.%$<>,%s|]-:%s*(.*)')
        if rest then
            local t = rest:match('^([%w_]+)')
            if t and config.SIGNAL_TYPES[t] then return 'signal' end
            if rest:match('^%(%)%s*=>') then return 'unknown' end -- alias-expanded
            return 'not_signal'
        end
        if line:match('%(method%)') then return 'not_signal' end
    end
    return 'unknown'
end

---Pick the LSP client for hover requests.
---@param kind 'ts'|'ng'
local function get_hover_client(buf, kind)
    if kind == 'ng' then
        return vim.lsp.get_clients({ bufnr = buf, name = 'angularls' })[1]
    end
    for _, name in ipairs({ 'vtsls', 'ts_ls', 'tsserver' }) do
        local c = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
        if c then return c end
    end
end

---Check the declaration site of a candidate: is the target line a signal
---declaration? Catches computed() and typed decls that hover cannot resolve.
---@param loc table  LSP Location|LocationLink
---@return boolean
local function definition_is_signal(loc)
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetSelectionRange
    if not uri or not range then return false end
    local path = vim.uri_to_fname(uri)
    local f = io.open(path, 'r')
    if not f then return false end
    local lineno, text = range.start.line + 1, nil
    local i = 0
    for l in f:lines() do
        i = i + 1
        if i == lineno then text = l break end
    end
    f:close()
    if not text then return false end
    -- `x = signal(...)` / `x = input.required(...)` style
    local callee = text:match('=%s*([%w_]+)%s*[%(<]')
        or text:match('=%s*([%w_]+)%.required%s*[%(<]')
    if callee and (config.SIGNAL_APIS[callee] or config.SIGNAL_APIS_REQUIRED[callee]) then
        return true
    end
    -- `x: Signal<...>` / `abstract value: WritableSignal<...>` style
    local t = text:match(':%s*([%w_]+)%s*<')
    return (t and config.SIGNAL_TYPES[t]) == true
end

-- ## Cycle bookkeeping ## --

---Range key for set membership: "{sr},{sc},{er},{ec}".
local function rk(range)
    return range[1] .. ',' .. range[2] .. ',' .. range[3] .. ',' .. range[4]
end

---Reverse rk(): "sr,sc,er,ec" → {sr, sc, er, ec} as numbers.
local function split_key(key)
    local sr, sc, er, ec = key:match('^(%d+),(%d+),(%d+),(%d+)$')
    return { tonumber(sr), tonumber(sc), tonumber(er), tonumber(ec) }
end

---Drop a cycle's debounce timer (if any) and clear the cycle entry.
local function drop_cycle(buf)
    local c = cycles[buf]
    if c and c.timer then
        c.timer:stop()
        if not c.timer:is_closing() then c.timer:close() end
    end
    cycles[buf] = nil
end

---One redraw pass: clear NS once, emit (Layer 1 - rejections) + Layer 2.
local function redraw(buf, cycle)
    vim.api.nvim_buf_clear_namespace(buf, config.NS, 0, -1)
    for key in pairs(cycle.l1_painted) do
        if not cycle.l2_rejected[key] then
            mark.place(buf, split_key(key))
        end
    end
    for key in pairs(cycle.l2_verified) do
        mark.place(buf, split_key(key))
    end
end

---Schedule a redraw for the buf's current cycle. New responses reset the
---timer so the redraw fires after the burst of verifications settles.
local function schedule_redraw(buf)
    local c = cycles[buf]
    if not c then return end
    if c.timer then
        c.timer:stop()
        if not c.timer:is_closing() then c.timer:close() end
    end
    c.timer = vim.uv.new_timer()
    c.timer:start(config.REDRAW_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
        local cur = cycles[buf]
        if cur and cur.timer == c.timer then
            redraw(buf, cur)
            cycles[buf] = nil
        end
    end))
end

-- ## Cycle API (called by init.lua's orchestrator) ## --

---Start a new cycle for `buf`. If a previous cycle is still in flight it
---gets discarded (its in-flight responses will be dropped as stale).
---L1 paint and L2 verification will mutate the new cycle and call
---schedule_redraw; the final redraw fires REDRAW_DEBOUNCE_MS after the
---last L2 activity (or immediately if there are no L2 candidates at all,
---since verify_candidates always schedules a final redraw).
function M.start_cycle(buf)
    drop_cycle(buf)
    cycles[buf] = { l1_painted = {}, l2_verified = {}, l2_rejected = {}, timer = nil }
end

---Layer 1 has painted `range` into the cycle for `buf`.
function M.note_l1_paint(buf, range)
    local c = cycles[buf]
    if not c then return end
    c.l1_painted[rk(range)] = true
end

-- ## Candidate collection ## --

---Collect Layer-2 candidates in an angular tree. Bare identifiers that ARE
---in the Layer-1 signal set are still candidates — we want Layer 2 to be
---able to disprove them (template locals that shadow a class signal name).
---@param root userdata  treesitter node to iterate
---@param source integer buffer handle for get_node_text
---@param names table<string, boolean>  signal name set
---@param out table[]  (optional) list to append to
function M.template_candidates(root, source, names, out)
    out = out or {}
    for _, node in queries.template:iter_captures(root, source) do
        local name = vim.treesitter.get_node_text(node, source)
        local sr, sc, er, ec = node:range()
        if treesitter.is_member_access(node) then
            local p = node:parent()
            if p:type() == 'call_expression' then p = p:parent() end
            out[#out + 1] = {
                key   = vim.treesitter.get_node_text(p, source),
                range = { sr, sc, er, ec },
                kind  = 'ng',
                from_l1 = false,
            }
        else
            out[#out + 1] = {
                key   = name,
                range = { sr, sc, er, ec },
                kind  = 'ng',
                from_l1 = names[name] == true,
            }
        end
    end
    return out
end

-- ## Verification ## --

---Walk an LSP definition result, returning both the first file referenced
---and whether any of the declaration sites look like a signal.
---@return string|nil file, boolean is_signal
local function inspect_definition(dresult)
    if not dresult then return nil, false end
    local locs = vim.islist(dresult) and dresult or { dresult }
    local file, is_signal = nil, false
    for _, loc in ipairs(locs) do
        local uri = loc.uri or loc.targetUri
        if uri and not file then
            file = vim.uri_to_fname(uri)
        end
        if definition_is_signal(loc) then
            is_signal = true
            break
        end
    end
    return file, is_signal
end

---Verify candidates via hover and record verdicts into the cycle. A
---`not_signal` verdict on a Layer-1 claim adds the range to the cycle's
---rejected set, so the redraw pass will skip it.
---@param candidates table[]  {key, range, kind, from_l1?}
function M.verify_candidates(buf, candidates)
    local cache = hover_cache[buf]
    if not cache then
        cache = {}
        hover_cache[buf] = cache
    end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local uri = vim.uri_from_bufnr(buf)
    local current_file = vim.uri_to_fname(uri)
    local cycle = cycles[buf]

    for _, cand in ipairs(candidates) do
        local known = cache[cand.key]
        if known and known.verdict == true then
            if cycle then cycle.l2_verified[rk(cand.range)] = true end
        elseif not known then
            local client = get_hover_client(buf, cand.kind)
            if not client then return end

            -- Mark as pending to prevent duplicate requests within the
            -- same buffer state. If the request fails, we delete this
            -- entry so the next scan retries.
            cache[cand.key] = { verdict = false, file = nil }

            local pos = { line = cand.range[1], character = cand.range[2] }
            local key = cand.key
            local range_key = rk(cand.range)
            local from_l1 = cand.from_l1
            local captured_cycle = cycle

            local function store(entry)
                cache[key] = entry
                if not vim.api.nvim_buf_is_valid(buf) then return end
                if vim.api.nvim_buf_get_changedtick(buf) ~= tick then return end
                -- Drop the verdict if a newer cycle has already started
                -- (e.g. user typed again and the orchestrator called
                -- start_cycle).  Without this check, an in-flight hover
                -- response from the previous cycle would silently
                -- contaminate the new cycle.
                if captured_cycle ~= cycles[buf] then return end
                if entry.verdict then
                    captured_cycle.l2_verified[range_key] = true
                elseif from_l1 then
                    captured_cycle.l2_rejected[range_key] = true
                end
                schedule_redraw(buf)
            end

            client:request('textDocument/hover', {
                textDocument = { uri = uri },
                position = pos,
            }, function(err, result)
                if err then
                    cache[key] = nil
                    schedule_redraw(buf)
                    return
                end
                local hover_verdict = result
                    and classify_hover(hover_text(result.contents))
                    or 'unknown'

                client:request('textDocument/definition', {
                    textDocument = { uri = uri },
                    position = pos,
                }, function(derr, dresult)
                    if derr or not dresult then
                        local final = (hover_verdict == 'signal') and true or false
                        store({ verdict = final, file = current_file })
                        return
                    end
                    local file, is_signal = inspect_definition(dresult)
                    local final
                    if hover_verdict == 'signal' then
                        final = true
                    elseif hover_verdict == 'not_signal' then
                        final = false
                    else
                        final = is_signal
                    end
                    store({ verdict = final, file = file or current_file })
                end, buf)
            end, buf)
        end
    end

    -- Schedule a final redraw so the cycle flushes even when every
    -- candidate was a cache hit (no hover request fires) or when the
    -- candidate list is empty.
    schedule_redraw(buf)
end

-- ## Orchestrators ## --

---Layer 2 pass for a typescript buffer. Consumes a TsBufState built by
---treesitter.build_ts_state (no re-parse) and the TS L2 candidate list
---collected during treesitter.paint_ts_state (the unified pass over
---queries.ts_member — see pass 2.3). Inline template regions add their
---own template candidates to the same list before verification.
---@param state angular.TsBufState
---@param ts_candidates table[]  L2 candidates from paint_ts_state
function M.lsp_scan_ts(state, ts_candidates)
    if not state then return end
    local buf = state.buf
    for _, t in ipairs(state.template_roots) do
        local names = t.class and t.class.names or {}
        M.template_candidates(t.root, state.source, names, ts_candidates)
    end
    M.verify_candidates(buf, ts_candidates)
end

---Layer 2 pass for an htmlangular buffer. Consumes an HtmlBufState.
function M.lsp_scan_html(state)
    if not state then return end
    M.verify_candidates(state.buf, M.template_candidates(state.ng_root, state.source, state.names))
end

-- ## Cache management ## --

---Drop all cache entries whose symbol is defined in the given file.
---Called from the BufWritePost on `*.ts` so only entries that could
---actually be affected by the change are re-verified.
function M.invalidate_file(file_path)
    for buf, by_key in pairs(hover_cache) do
        for key, entry in pairs(by_key) do
            if entry.file == file_path then
                by_key[key] = nil
            end
        end
        if next(by_key) == nil then
            hover_cache[buf] = nil
        end
    end
end

---Drop all cache entries. Used by :SignalHighlight refresh.
function M.invalidate_all()
    hover_cache = {}
    for buf, _ in pairs(cycles) do
        drop_cycle(buf)
    end
end

---Drop cache entries for a single buffer. Used by BufDelete.
function M.invalidate_buffer(buf)
    hover_cache[buf] = nil
    drop_cycle(buf)
end

return M
