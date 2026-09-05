-- Layer 1: synchronous treesitter-based signal highlighting.
-- Finds class members initialized with signal APIs and highlights their
-- declarations and usages in .ts and templates. False positives are
-- corrected asynchronously by lsp.lua.
--
-- Builds a BufState (see below) once per cycle. Both layers consume it so
-- the .ts / angular parses and the find_declarations walk happen exactly
-- once per scan (see docs/signal-highlight-refactor.md pass 2.2).

local config  = require('angular-tools.features.signal-highlight.config')
local queries = require('angular-tools.features.signal-highlight.queries')
local mark    = require('angular-tools.features.signal-highlight.mark')
local files   = require('angular-tools.core.files')

local M = {}

-- ## BufState ## --
-- One struct per cycle (one full_scan_ts/html call), built once, read by
-- both layers. Holds the parsed tree(s) and the derived per-class signal
-- sets so the lsp.lua pass doesn't have to re-parse or re-walk.

---@class angular.TsBufState
---@field buf integer
---@field source integer         handle for treesitter.get_node_text
---@field ts_tree userdata       parsed typescript tree
---@field ts_root userdata       tree:root()
---@field classes table[]        {node=class_node, names=set<string>}
---@field decl_ranges table[]    {sr,sc,er,ec} list, painted by Layer 1
---@field template_roots table[] {root=userdata, class=entry|nil}

---@class angular.HtmlBufState
---@field buf integer
---@field source integer
---@field ng_tree userdata       parsed angular tree
---@field ng_root userdata       tree:root()
---@field names table<string, boolean>  merged signal name set
---@field ts_path string         component .ts path the names came from

-- ## Pure helpers ## --

---Is this callee a signal-creating API?
---@param fn string|nil    plain callee, e.g. "signal"
---@param base string|nil  member callee base, e.g. "input"
---@param prop string|nil  member callee prop, e.g. "required"
local function is_signal_api(fn, base, prop)
    if fn then
        return config.SIGNAL_APIS[fn] == true
    end
    return config.SIGNAL_APIS_REQUIRED[base] == true and prop == 'required'
end

---Walk up the tree to find the enclosing class declaration node, if any.
local function enclosing_class(node)
    local cur = node
    while cur do
        local t = cur:type()
        if t == 'class_declaration' or t == 'class' then return cur end
        cur = cur:parent()
    end
end

---Is this identifier the property/call side of `obj.prop` / `obj.prop()`?
---(angular grammar: member_expression has fields object / property / call)
local function is_member_access(node)
    local parent = node:parent()
    if not parent then return false end
    -- obj.prop  -> identifier directly under member_expression, not as object
    if parent:type() == 'member_expression' then
        return parent:field('object')[1] ~= node
    end
    -- obj.prop() -> identifier under call_expression under member_expression(call:)
    if parent:type() == 'call_expression' then
        local gp = parent:parent()
        return gp ~= nil and gp:type() == 'member_expression'
            and gp:field('call')[1] == parent
    end
    return false
end

---Scan a typescript syntax tree for signal declarations, scoped per class.
---@return table[] classes     list of {node=class_node, names=set<string>}
---@return table[] decl_nodes  nodes of the declaration identifiers
local function find_declarations(root, source)
    local by_id, classes, nodes = {}, {}, {}
    for _, match in queries.decl_ts:iter_matches(root, source) do
        local name_node, fn, base, prop
        for id, match_nodes in pairs(match) do
            local cap = queries.decl_ts.captures[id]
            local node = match_nodes[#match_nodes]
            local text = vim.treesitter.get_node_text(node, source)
            if cap == 'name' then
                name_node = node
            elseif cap == 'fn' then
                fn = text
            elseif cap == 'fn_base' then
                base = text
            elseif cap == 'fn_prop' then
                prop = text
            end
        end
        if name_node and is_signal_api(fn, base, prop) then
            local class_node = enclosing_class(name_node)
            if class_node then
                local id = class_node:id()
                local entry = by_id[id]
                if not entry then
                    entry = { node = class_node, names = {} }
                    by_id[id] = entry
                    classes[#classes + 1] = entry
                end
                entry.names[vim.treesitter.get_node_text(name_node, source)] = true
                nodes[#nodes + 1] = name_node
            end
        end
    end
    return classes, nodes
end

-- ## Internal ## --

---Highlight identifiers in an angular tree that are in the signal name set.
---Used for both inline template regions in TS buffers and the whole
---htmlangular buffer. Paints directly via mark.place; the orchestrator
---clears the namespace before calling, so no per-paint clear is needed.
---@param on_mark fun(range: number[])|nil
local function paint_template_usages(buf, root, source, names, on_mark)
    for _, node in queries.template:iter_captures(root, source) do
        if not is_member_access(node) and names[vim.treesitter.get_node_text(node, source)] then
            local sr, sc, er, ec = node:range()
            local range = { sr, sc, er, ec }
            mark.place(buf, range)
            if on_mark then on_mark(range) end
        end
    end
end

-- ## TS buffer scan ## --

---Build the per-cycle state for a typescript buffer: parsed tree, classes,
---template regions (angular-injected inline templates), and a paint list.
---Returns nil if the parser isn't available or the parse fails.
---@return angular.TsBufState|nil
function M.build_ts_state(buf)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, 'typescript')
    if not ok or not parser then return nil end
    local tree = parser:parse()[1]
    if not tree then return nil end

    local classes, decl_nodes = find_declarations(tree:root(), buf)
    local decl_ranges = {}
    for _, node in ipairs(decl_nodes) do
        local sr, sc, er, ec = node:range()
        decl_ranges[#decl_ranges + 1] = { sr, sc, er, ec }
    end

    -- usages in inline templates: angular-injected regions.
    -- NOTE: the @Component decorator sits *outside* the class_declaration
    -- node (it belongs to the export_statement), so a template region
    -- precedes its class. Associate each region with the nearest class
    -- that starts after it.
    local template_roots = {}
    parser:parse(true)
    parser:for_each_tree(function(child_tree, child_parser)
        if child_parser:lang() ~= 'angular' then return end
        local child_root = child_tree:root()
        local region_start = child_root:range()

        local best
        for _, entry in ipairs(classes) do
            local cs, _, ce = entry.node:range()
            if region_start >= cs and region_start <= ce then
                best = entry -- decorator inside class node (non-exported class)
                break
            end
            if cs >= region_start and (not best or cs < best.node:range()) then
                best = entry
            end
        end
        template_roots[#template_roots + 1] = {
            root = child_root,
            class = best,
        }
    end)

    return {
        buf = buf,
        source = buf,
        ts_tree = tree,
        ts_root = tree:root(),
        classes = classes,
        decl_ranges = decl_ranges,
        template_roots = template_roots,
    }
end

---Paint Layer 1 marks for a TS BufState: declarations + `this.<name>`
---usages (in a single unified pass over ts_member, see pass 2.3) + usages
---inside each associated inline template region. Calls `on_mark(range)`
---after every mark so the orchestrator can record the range into the LSP
---cycle (used by the redraw pass).
---@param on_mark fun(range: number[])|nil
---@return table[]  Layer-2 candidates: {key, range, kind, from_l1?}
function M.paint_ts_state(state, on_mark)
    if not state then return {} end
    local buf = state.buf
    vim.api.nvim_buf_clear_namespace(buf, config.NS, 0, -1)
    for _, range in ipairs(state.decl_ranges) do
        mark.place(buf, range)
        if on_mark then on_mark(range) end
    end

    -- Single unified pass over every `<obj>.<prop>` member expression
    -- (queries.ts_member). For each, dispatch in one step:
    --   this.<name> inside a class that has <name> as a signal → L1 mark.
    --   anything else → L2 candidate.
    -- The old code had a separate `usage_ts` query for L1 and a
    -- "skip Layer 1 hits" loop inside lsp.ts_candidates.  That skip loop
    -- is gone: there is nothing to skip because L1 marks are produced
    -- here, alongside the L2 candidate set, in one iteration.
    local l2_candidates = {}
    for _, node in queries.ts_member:iter_captures(state.ts_root, state.source) do
        local parent = node:parent()
        local obj = parent:field('object')[1]
        local name = vim.treesitter.get_node_text(node, state.source)
        local sr, sc, er, ec = node:range()
        local range = { sr, sc, er, ec }

        local is_l1 = false
        if obj and obj:type() == 'this' then
            for _, entry in ipairs(state.classes) do
                local cs, _, ce = entry.node:range()
                local nr = node:range()
                if nr >= cs and nr <= ce and entry.names[name] then
                    is_l1 = true
                    break
                end
            end
        end

        if is_l1 then
            mark.place(buf, range)
            if on_mark then on_mark(range) end
        else
            l2_candidates[#l2_candidates + 1] = {
                key   = vim.treesitter.get_node_text(parent, state.source),
                range = range,
                kind  = 'ts',
            }
        end
    end

    for _, t in ipairs(state.template_roots) do
        if t.class then
            paint_template_usages(buf, t.root, buf, t.class.names, on_mark)
        end
    end
    return l2_candidates
end

---Backwards-compatible entrypoint: build state, then paint.
function M.scan_ts_buffer(buf)
    M.paint_ts_state(M.build_ts_state(buf))
end

-- ## External HTML ## --

---Compute the signal name set for a component .ts file on disk.
---@return table<string, boolean>|nil
function M.signal_names_from_file(ts_path)
    local f = io.open(ts_path, 'r')
    if not f then return nil end
    local src = f:read('*a')
    f:close()

    local ok, parser = pcall(vim.treesitter.get_string_parser, src, 'typescript')
    if not ok then return nil end
    local tree = parser:parse()[1]
    if not tree then return nil end

    -- merge all classes: an external template belongs to one component, but
    -- name collisions across classes in one file are rare and acceptable here.
    local merged = {}
    local classes = select(1, find_declarations(tree:root(), src))
    for _, entry in ipairs(classes) do
        for name in pairs(entry.names) do
            merged[name] = true
        end
    end
    return merged
end

---Build the per-cycle state for an htmlangular buffer: parsed tree and the
---merged signal name set from the sibling .ts file.
---@return angular.HtmlBufState|nil
function M.build_html_state(buf)
    local html_path = vim.api.nvim_buf_get_name(buf)
    -- Use the shared core/files helper: get_base strips a known Angular
    -- extension, so this only matches the `.component.html` convention.
    -- We then re-attach `.component.ts` to find the sibling component file.
    local base = files.get_base(html_path)
    if not base then return nil end
    local ts_path = base .. '.component.ts'

    local names = M.signal_names_from_file(ts_path)
    if not names or vim.tbl_isempty(names) then return nil end

    local ok, parser = pcall(vim.treesitter.get_parser, buf, 'angular')
    if not ok or not parser then return nil end
    local tree = parser:parse()[1]
    if not tree then return nil end

    return {
        buf = buf,
        source = buf,
        ng_tree = tree,
        ng_root = tree:root(),
        names = names,
        ts_path = ts_path,
    }
end

---Paint Layer 1 marks for an HTML BufState: bare identifiers in the
---angular tree that are in the signal name set.
---@param on_mark fun(range: number[])|nil
function M.paint_html_state(state, on_mark)
    if not state then return end
    local buf = state.buf
    vim.api.nvim_buf_clear_namespace(buf, config.NS, 0, -1)
    paint_template_usages(buf, state.ng_root, buf, state.names, on_mark)
end

---Backwards-compatible entrypoint: build state, then paint.
function M.scan_html_buffer(buf)
    M.paint_html_state(M.build_html_state(buf))
end

-- Re-exports for tests / external use.
M.find_declarations = find_declarations
M.is_member_access  = is_member_access

return M
