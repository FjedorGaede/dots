-- LSP helpers: cross-server deduplication for definition / references /
-- implementations. Some buffers have multiple LSP servers attached
-- (e.g. .ts files in Angular projects have both vtsls and angularls).
-- Each server returns its own list, often with overlapping entries
-- for the same symbol. These helpers fold the lists together and
-- show the union in a single Snacks picker.

local M = {}

--- Deduplicate LSP locations by uri + start line + start character.
--- Handles both `Location` (uri / range) and `LocationLink`
--- (targetUri / targetSelectionRange).
---@param locations table[]
---@return table[]  unique locations, preserving first-occurrence order
function M.dedup_locations(locations)
    local seen = {}
    local result = {}
    for _, loc in ipairs(locations or {}) do
        local uri = loc.uri or loc.targetUri
        local range = loc.range or loc.targetSelectionRange
        if uri and range and range.start then
            local key = uri .. "|" .. range.start.line .. "|" .. range.start.character
            if not seen[key] then
                seen[key] = true
                table.insert(result, loc)
            end
        end
    end
    return result
end

--- Convert LSP locations to Snacks picker items.
--- Snacks expects `file` (full path) and `pos = { lnum, col }` (1-indexed tuple),
--- not the LSP-style `filename` / `lnum` / `col` fields.
---@param locations table[]  deduplicated LSP locations
---@return table[]  items with file, pos, text
function M.locations_to_items(locations)
    local items = {}
    for _, loc in ipairs(locations or {}) do
        local uri = loc.uri or loc.targetUri
        local range = loc.range or loc.targetSelectionRange
        if uri and range and range.start then
            local fname = vim.uri_to_fname(uri)
            local lnum = range.start.line + 1
            local col = range.start.character + 1
            local text = ""
            local ok, lines = pcall(vim.fn.readfile, fname, "", lnum)
            if ok and lines and lines[1] then
                text = lines[1]
            end
            table.insert(items, {
                file = fname,
                pos = { lnum, col },
                text = text,
            })
        end
    end
    return items
end

--- Send a request to all attached LSP clients and invoke a callback
--- with a single deduplicated list of locations.
---@param method string  e.g. "textDocument/definition"
---@param callback fun(locations: table[])
function M.request_all_locations(method, callback)
    local clients = vim.lsp.get_clients({ bufnr = 0, method = method })
    if #clients == 0 then
        callback({})
        return
    end
    local params = vim.lsp.util.make_position_params(0, "utf-8")
    vim.lsp.buf_request_all(0, method, params, function(results)
        local all = {}
        for _, res in pairs(results or {}) do
            if res and res.result then
                local r = res.result
                if vim.islist(r) then
                    vim.list_extend(all, r)
                elseif r.uri or r.targetUri then
                    table.insert(all, r)
                end
            end
        end
        callback(M.dedup_locations(all))
    end)
end

--- Show a Snacks picker with the given LSP locations.
---@param locations table[]  deduplicated locations
---@param title string
function M.show_locations(locations, title)
    local items = M.locations_to_items(locations)
    if #items == 0 then
        vim.notify("No " .. title:lower() .. " found", vim.log.levels.INFO)
        return
    end
    Snacks.picker({
        items = items,
        format = "file",
        title = title,
    })
end

--- Go to definition, falling back to references when no remote definition
--- is found. Mirrors the previous gd behavior but with cross-server dedup.
function M.go_to_definition_or_references()
    local cur = vim.api.nvim_win_get_cursor(0)
    M.request_all_locations("textDocument/definition", function(defs)
        local has_remote = false
        for _, loc in ipairs(defs) do
            local range = loc.range or loc.targetSelectionRange
            if range and range.start and (range.start.line + 1) ~= cur[1] then
                has_remote = true
                break
            end
        end
        if has_remote then
            M.show_locations(defs, "Definitions")
        else
            M.request_all_locations("textDocument/references", function(refs)
                M.show_locations(refs, "References")
            end)
        end
    end)
end

--- Show deduplicated references in a Snacks picker.
function M.references()
    M.request_all_locations("textDocument/references", function(refs)
        M.show_locations(refs, "References")
    end)
end

--- Show deduplicated implementations in a Snacks picker.
function M.implementations()
    M.request_all_locations("textDocument/implementation", function(impls)
        M.show_locations(impls, "Implementations")
    end)
end

return M
