-- selector-usages: detect the selector string in an Angular @Component
-- decorator via the TypeScript/JavaScript treesitter grammar, and search
-- for its usages (opening tag, closing tag, selector="..." attribute) in
-- the project. Optionally underlines the string under the cursor.
--
-- Public API:
--   M.detect()        -> { selector, lnum, col_start, col_end } | nil
--   M.find_usages(s)  -> opens Snacks.picker.grep with combined pattern
--   M.setup(cfg)      -> enables highlight autocmd and (optionally) keymap

local M = {}

local HL_NAMESPACE = "angular_selector_underline"
local HL_GROUP = "angular_selector_underline"

--- Return the unquoted text of a string / template_string node, or nil
--- if the node isn't a string-like type.
---@param node userdata
---@param bufnr number
---@return string|nil
local function unquoted_text(node, bufnr)
    if not node then return nil end
    local t = node:type()
    if t ~= "string" and t ~= "template_string" then return nil end
    local text = vim.treesitter.get_node_text(node, bufnr)
    if not text or #text < 2 then return nil end
    local first, last = text:sub(1, 1), text:sub(-1)
    if first == last and (first == '"' or first == "'" or first == "`") then
        return text:sub(2, -2)
    end
    return text
end

--- Walk up the AST from the cursor and confirm the chain:
---   cursor -> string -> pair (key: "selector") -> object -> arguments
---         -> call_expression (function: "Component") -> decorator
---@return { selector: string, lnum: number, col_start: number, col_end: number }|nil
function M.detect()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    if ft ~= "typescript" and ft ~= "typescriptreact"
        and ft ~= "javascript" and ft ~= "javascriptreact" then
        return nil
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok_parser or not parser then return nil end

    local cursor = vim.api.nvim_win_get_cursor(0)
    -- treesitter uses 0-based row/col
    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { cursor[1] - 1, cursor[2] } })
    if not node then return nil end

    -- Walk up to the nearest string / template_string
    while node and node:type() ~= "string" and node:type() ~= "template_string" do
        node = node:parent()
    end
    if not node then return nil end

    local selector = unquoted_text(node, bufnr)
    if not selector or selector == "" then return nil end

    -- Validate the structural chain
    local pair = node:parent()
    if not pair or pair:type() ~= "pair" then return nil end

    local key_node = pair:field("key")[1]
    if not key_node or vim.treesitter.get_node_text(key_node, bufnr) ~= "selector" then
        return nil
    end

    local object = pair:parent()
    if not object or object:type() ~= "object" then return nil end

    local args = object:parent()
    if not args or args:type() ~= "arguments" then return nil end

    local call = args:parent()
    if not call or call:type() ~= "call_expression" then return nil end

    local fn_node = call:field("function")[1]
    if not fn_node or fn_node:type() ~= "identifier" then return nil end
    if vim.treesitter.get_node_text(fn_node, bufnr) ~= "Component" then return nil end

    local decorator = call:parent()
    if not decorator or decorator:type() ~= "decorator" then return nil end

    local sr, sc, _, ec = node:range()
    return {
        selector = selector,
        lnum = sr + 1,           -- 1-based line
        col_start = sc + 1,      -- skip the opening quote (0-based, inclusive)
        col_end = ec - 1,        -- stop before the closing quote (0-based, exclusive)
    }
end

--- Escape a string for use as a literal segment inside a ripgrep regex.
--- IMPORTANT: ripgrep uses `\X` (not `\%X` like some other engines) to
--- escape a metacharacter. Producing `%-` matches nothing silently.
local function rg_escape(s)
    return (s:gsub("[%-%+%*%?%[%]%^%$%.%(%)%|]", "\\%1"))
end

--- Search the project for usages of the selector and show them in a
--- Snacks picker. Pattern matches:
---   <selector           (opening tag, possibly with attrs)
---   </selector>         (closing tag)
---   selector="selector" (attribute form)
---
--- Uses a custom async finder (rg via vim.system) instead of
--- Snacks.picker.grep, which avoids the default `wo` config that
--- some Snacks versions trip on with "Illegal character <d>" in
--- nvim_set_option_value. Falls back to a quickfix list if Snacks
--- still errors at runtime.
function M.find_usages(selector)
    if not selector or selector == "" then
        vim.notify("No selector to search for", vim.log.levels.WARN)
        return
    end
    local e = rg_escape(selector)
    local pattern = table.concat({
        "<" .. e,
        "</" .. e .. ">",
        "selector=\"" .. e .. "\"",
    }, "|")

    local title = "Selector usages: " .. selector
    local cmd = { "rg", "--color=never", "-e", pattern, "--no-heading", "-n", "--" }

    local function open_quickfix(items)
        local qf = {}
        for _, it in ipairs(items) do
            table.insert(qf, {
                filename = it.file,
                lnum = it.pos[1],
                col = it.pos[2],
                text = it.text,
            })
        end
        vim.fn.setqflist({}, " ", { title = title, items = qf })
        if #qf > 0 then
            vim.cmd("copen")
        else
            vim.notify("No usages found for selector '" .. selector .. "'", vim.log.levels.INFO)
        end
    end

    -- Build items via rg
    local function build_items(done)
        vim.system(cmd, { text = true }, function(result)
            local items = {}
            if result.code <= 1 then
                for _, line in ipairs(vim.split(result.stdout or "", "\n", { plain = true })) do
                    if line ~= "" then
                        local f, l, content = line:match("^([^:]+):(%d+):(.*)$")
                        if f then
                            table.insert(items, {
                                file = f,
                                pos = { tonumber(l), 1 },
                                text = content,
                            })
                        end
                    end
                end
            end
            done(items, result)
        end)
    end

    build_items(function(items, result)
        vim.schedule(function()
            if result.code and result.code > 1 then
                vim.notify("rg error: " .. (result.stderr or "unknown"), vim.log.levels.ERROR)
                return
            end
            if not items or #items == 0 then
                vim.notify("No usages found for selector '" .. selector .. "'", vim.log.levels.INFO)
                return
            end
            -- Try Snacks first; if its window setup throws, fall back to quickfix
            local ok, err = pcall(function()
                Snacks.picker({
                    source = "selector_usages",
                    format = "file",
                    title = title,
                    items = items,
                })
            end)
            if not ok then
                vim.notify("Snacks picker failed (" .. tostring(err) .. "), using quickfix", vim.log.levels.WARN)
                open_quickfix(items)
            end
        end)
    end)
end

--- Underline the selector string under the cursor, live. Uses an isolated
--- namespace + augroup so it's safe to load/unload.
function M.setup_highlight()
    local group = vim.api.nvim_create_augroup(HL_GROUP, { clear = true })
    local ns = vim.api.nvim_create_namespace(HL_NAMESPACE)

    local function update()
        local bufnr = vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        local hit = M.detect()
        if hit then
            vim.api.nvim_buf_add_highlight(
                bufnr, ns, "Underlined",
                hit.lnum - 1, hit.col_start, hit.col_end
            )
        end
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter", "WinEnter" }, {
        group = group,
        callback = update,
    })
end

function M.setup(cfg)
    cfg = cfg or {}
    if cfg.highlight ~= false then
        M.setup_highlight()
    end
    if cfg.keymap then
        vim.keymap.set("n", cfg.keymap, function()
            local hit = M.detect()
            if hit then
                M.find_usages(hit.selector)
            else
                vim.notify("Not on an Angular component selector", vim.log.levels.WARN)
            end
        end, { desc = "[A]ngular: selector [u]sages" })
    end
end

return M
