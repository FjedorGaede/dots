-- Status bar configuration
local function get_modified_indicator()
  if vim.bo.modified then
    return "󰆓"
  end
end

local function todo()
  local doing = require("doing")
  local status = doing.status()
  local current_todo = status:match("^(.-)%+")
  if current_todo == nil then
    current_todo = status
  end
  return current_todo
end

-- Customizaion of build in MiniStatusLine.section_filename-
---@param args __statusline_args
---
---@return __statusline_section
local section_filename = function(args)
  -- In terminal always use plain name
  if vim.bo.buftype == "terminal" then
    return "%t"
  end
  -- Always show relative path
  local format = "%f"

  if args.show_modified then
    format = format .. "%m"
  end

  return format .. "%r"
end

local function get_short_file_info()
  local filetype = vim.bo.filetype

  -- Don't show anything if there is no filetype
  if filetype == "" then
    return ""
  end

  local has_devicons, devicons = pcall(require, "nvim-web-devicons")
  if not has_devicons then
    return
  end
  local icon = devicons.get_icon(vim.fn.expand("%:t"), nil, { default = true })

  if filetype == "neotest-summary" then -- fzf gets special treatment here
    filetype = "Neotest Summary"
    icon = "󰙨"
  end

  if filetype == "fzf" then -- fzf gets special treatment here
    filetype = "FZF"
    icon = ""
  end

  if filetype == "snacks_terminal" then
    local file_name = vim.fn.expand("%:t")

    if file_name == "lazygit" then -- lazygit gets special treatment here
      filetype = "lazygit"
      icon = ""
    end
  end

  return string.format("%s %s", icon, filetype)
end

local hide_lsps_for_filetypes = {
  "neotest-summary",
  "lazygit",
  "fzf",
}

local function lsps_for_filetypes()
  local filetype = vim.bo.filetype
  if vim.tbl_contains(hide_lsps_for_filetypes, filetype) then
    return ""
  end

  local lsp_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
  local lsp_client_names = {}
  for _, client in pairs(lsp_clients) do
    table.insert(lsp_client_names, client.name)
  end

  return "[" .. (#lsp_client_names > 0 and table.concat(lsp_client_names, ", ") or "no lsps") .. "]"
end

local function get_git(trunc_width)
  local isTruncated = MiniStatusline.is_truncated(trunc_width)
  local git = ""

  if isTruncated then
    return git
  end

  local long_git = git .. " " .. (vim.b and vim.b.minigit_summary and vim.b.minigit_summary.head_name or "")

  return long_git
end

-- Install statusline plugin
addPackage("nvim-mini/mini.statusline")

-- Configure statusline
-- Using default configuration for now
require("mini.statusline").setup({
    use_icons = true,
    content = {
        active = function()
            local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
            local git = get_git(120)
            local diff = MiniStatusline.section_diff({ trunc_width = 75 })
            local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
            local filename = section_filename({ trunc_width = 140 })
            local modified_indicator = get_modified_indicator()
            -- local fileinfo_long = MiniStatusline.section_fileinfo({ trunc_width = 140 })
            local fileinfo = get_short_file_info()
            -- local location = MiniStatusline.section_location({ trunc_width = 75 })
            -- local search = MiniStatusline.section_searchcount({ trunc_width = 75 })
            local reg = vim.fn.reg_recording()
            local macro = "@" .. reg
            -- local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
            local lsp_client_name = lsps_for_filetypes()

            local position = "%l / %L"

            local groups = {
                { hl = mode_hl, strings = { mode } },
                { hl = "MiniStatuslineDevinfo", strings = { git } },
                { hl = "MiniStatuslineDiagnostics", strings = { diagnostics } },
                { hl = "MiniStatuslineModifiedIndicator", strings = { modified_indicator } },
                "%<", -- Mark general truncate point
                { hl = "MiniStatuslineFilename", strings = { filename } },
                "%=", -- End left alignment
                -- { hl = "MiniStatuslineFilename", strings = { todo() } }, -- This is too much I think
                { hl = "MiniStatuslineFilename", strings = { position } },
                { hl = "MiniStatuslineFileinfo", strings = { fileinfo, lsp_client_name } },
            }

            if reg ~= "" then
                table.insert(groups, { hl = "MiniStatuslineMacro", strings = { macro } })
            end

            return MiniStatusline.combine_groups(groups)
        end,
    },
})

return {}
