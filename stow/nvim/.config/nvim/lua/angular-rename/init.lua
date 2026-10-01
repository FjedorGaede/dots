---@mod angular-rename Angular Component Rename Plugin for Neovim
---
--- Renames an Angular component and all its associated files, references,
--- selectors, class names, imports, and routing paths across the project.
---
--- Usage: Press <leader>ar while editing any Angular component file.
--- A form dialog prompts for the new name, then shows editable fields.

local utils = require("angular-rename.utils")

local M = {}

---@class AngularRenameConfig
---@field selector_prefix string|nil Override selector prefix (default: auto-detect or "app")
---@field dry_run boolean If true, only log what would happen without making changes
---@field log_level string "info"|"debug"|"warn"|"error"
local defaults = {
  selector_prefix = nil,
  dry_run = false,
  log_level = "info",
}

---@type AngularRenameConfig
M.config = vim.deepcopy(defaults)

--- Log a message
---@param msg string
---@param level string
local function log(msg, level)
  local levels = { debug = 0, info = 1, warn = 2, error = 3 }
  local config_level = levels[M.config.log_level] or 1
  local msg_level = levels[level] or 1
  if msg_level >= config_level then
    local hl = ({
      debug = "Comment",
      info = "Normal",
      warn = "WarningMsg",
      error = "ErrorMsg",
    })[level] or "Normal"
    vim.api.nvim_echo({ { "[angular-rename] " .. msg, hl } }, true, {})
  end
end

--- Close any open buffers for the given file paths
---@param paths string[]
local function close_buffers(paths)
  for _, path in ipairs(paths) do
    local abs = vim.fn.fnamemodify(path, ":p")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name == abs then
          if vim.bo[buf].modified then
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("silent! write")
            end)
          end
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  end
end

--- Execute the rename operation
---@param component table Detected component info
---@param new_name string New kebab-case name
---@param new_selector string New selector (e.g. "app-new-name")
---@param new_class string New class name (e.g. "NewNameComponent")
---@param project_root string
local function execute_rename(component, new_name, new_selector, new_class, project_root)
  local old_name = component.name
  local prefix = M.config.selector_prefix or component.prefix
  local old_pascal = utils.kebab_to_pascal(old_name) .. "Component"
  local new_pascal = new_class
  local old_selector = prefix .. "-" .. old_name
  local dir_name = vim.fn.fnamemodify(component.dir, ":t")

  -- Collect old file paths for buffer management
  local old_file_paths = {}
  for _, ext in ipairs(component.extensions) do
    table.insert(old_file_paths, component.dir .. "/" .. old_name .. ".component." .. ext)
  end

  -- Step 0: Save all open buffers
  vim.cmd("silent! wall")

  -- Step 1: Update content INSIDE the component files before renaming
  log("Updating component file contents...", "info")
  for _, ext in ipairs(component.extensions) do
    local filepath = component.dir .. "/" .. old_name .. ".component." .. ext
    if utils.file_exists(filepath) then
      local content = utils.read_file(filepath)
      if content then
        local new_content = content
        new_content = new_content:gsub(utils.escape_pattern(old_pascal), new_pascal)
        new_content = new_content:gsub(
          "selector:%s*['\"]" .. utils.escape_pattern(old_selector) .. "['\"]",
          "selector: '" .. new_selector .. "'"
        )
        new_content = new_content:gsub(
          utils.escape_pattern(old_name .. ".component.html"),
          new_name .. ".component.html"
        )
        for _, style_ext in ipairs({ "scss", "css", "less" }) do
          new_content = new_content:gsub(
            utils.escape_pattern(old_name .. ".component." .. style_ext),
            new_name .. ".component." .. style_ext
          )
        end
        if new_content ~= content then
          utils.write_file(filepath, new_content)
          log("  Updated: " .. vim.fn.fnamemodify(filepath, ":."), "debug")
        end
      end
    end
  end

  -- Step 2: Close buffers for old files
  close_buffers(old_file_paths)

  -- Step 3: Rename files
  log("Renaming component files...", "info")
  for _, ext in ipairs(component.extensions) do
    local old_file = component.dir .. "/" .. old_name .. ".component." .. ext
    local new_file = component.dir .. "/" .. new_name .. ".component." .. ext
    if utils.file_exists(old_file) then
      local ok, err = os.rename(old_file, new_file)
      if ok then
        log("  Renamed: " .. vim.fn.fnamemodify(old_file, ":.") .. " -> " .. vim.fn.fnamemodify(new_file, ":."), "debug")
      else
        log("  FAILED to rename " .. old_file .. ": " .. (err or "unknown error"), "error")
      end
    end
  end

  -- Step 4: Rename directory if it matches
  local new_dir = component.dir
  if dir_name == old_name then
    local parent = vim.fn.fnamemodify(component.dir, ":h")
    new_dir = parent .. "/" .. new_name
    log("Renaming directory...", "info")
    local ok, err = os.rename(component.dir, new_dir)
    if ok then
      log("  Renamed: " .. vim.fn.fnamemodify(component.dir, ":.") .. "/ -> " .. vim.fn.fnamemodify(new_dir, ":.") .. "/", "debug")
    else
      log("  FAILED to rename directory: " .. (err or "unknown error"), "error")
    end
  end

  -- Step 5: Project-wide replacements
  log("Updating references across project...", "info")

  local ts_files = utils.find_files(project_root, "**/*.ts")
  local html_files = utils.find_files(project_root, "**/*.html")
  local all_files = {}
  for _, f in ipairs(ts_files) do
    if not f:match("/node_modules/") and not f:match("/dist/") and not f:match("/.angular/") then
      table.insert(all_files, f)
    end
  end
  for _, f in ipairs(html_files) do
    if not f:match("/node_modules/") and not f:match("/dist/") and not f:match("/.angular/") then
      table.insert(all_files, f)
    end
  end

  local files_changed = 0
  for _, filepath in ipairs(all_files) do
    local content = utils.read_file(filepath)
    if content then
      local new_content = content

      -- Replace class name (in imports, declarations, providers, etc.)
      new_content = new_content:gsub(utils.escape_pattern(old_pascal), new_pascal)

      -- Replace selector usage in HTML templates
      new_content = new_content:gsub(utils.escape_pattern(old_selector), new_selector)

      -- Replace ALL import paths that reference the old directory name.
      -- This catches services, pipes, guards, models, etc. -- not just .component files.
      -- e.g. from './old-name/some.service' -> './new-name/some.service'
      --      from '../old-name/old-name.component' -> '../new-name/new-name.component'
      if dir_name == old_name then
        -- Match: /<old-name>/ in any import path and replace the directory segment
        new_content = new_content:gsub(
          "([\'\"].-)" .. utils.escape_pattern("/" .. old_name .. "/") .. "(.-[\'\"])",
          function(before, after)
            return before .. "/" .. new_name .. "/" .. after
          end
        )
        -- Also handle ./<old-name>/ at start of import path
        new_content = new_content:gsub(
          "([\'\"])" .. utils.escape_pattern("./" .. old_name .. "/") .. "(.-[\'\"])",
          function(before, after)
            return before .. "./" .. new_name .. "/" .. after
          end
        )
      end

      -- Replace component file references in import paths
      -- e.g. from './whatever/old-name.component' -> './whatever/new-name.component'
      new_content = new_content:gsub(
        "(['\"/])" .. utils.escape_pattern(old_name .. ".component"),
        "%1" .. new_name .. ".component"
      )

      if new_content ~= content then
        utils.write_file(filepath, new_content)
        files_changed = files_changed + 1
        log("  Updated: " .. vim.fn.fnamemodify(filepath, ":."), "debug")
      end
    end
  end

  log(string.format("Updated references in %d files", files_changed), "info")

  -- Step 6: Open the new component .ts file
  local new_ts = new_dir .. "/" .. new_name .. ".component.ts"
  if utils.file_exists(new_ts) then
    vim.cmd("edit " .. vim.fn.fnameescape(new_ts))
    log("Opened: " .. vim.fn.fnamemodify(new_ts, ":."), "info")
  end
end

---------------------------------------------------------------------------
-- NUI Form Dialog
---------------------------------------------------------------------------

--- Open the rename form using nui.nvim.
--- 3 Input fields (Name, Selector, Class) + a read-only preview Popup.
--- Tab/Shift-Tab to navigate, Enter to confirm, Esc to cancel.
---@param component table
---@param new_kebab string
---@param project_root string
local function open_dialog(component, new_kebab, project_root)
  -- Lazy-require nui.nvim (installed by plugins layer, loaded on demand)
  local Input = require("nui.input")
  local Popup = require("nui.popup")
  local Layout = require("nui.layout")

  local old_name = component.name
  local prefix = M.config.selector_prefix or component.prefix
  local new_pascal = utils.kebab_to_pascal(new_kebab)
  local new_selector = prefix .. "-" .. new_kebab
  local new_class = new_pascal .. "Component"
  local dir_name = vim.fn.fnamemodify(component.dir, ":t")

  -- Track current values from each input
  local values = {
    name = new_pascal,
    selector = new_selector,
    class = new_class,
  }

  -- Build preview lines
  local preview_lines = {}
  table.insert(preview_lines, "  Files:")
  for _, ext in ipairs(component.extensions) do
    table.insert(preview_lines, "    " .. old_name .. ".component." .. ext .. "  ->  " .. new_kebab .. ".component." .. ext)
  end
  if dir_name == old_name then
    table.insert(preview_lines, "")
    table.insert(preview_lines, "  Directory:")
    local parent_rel = vim.fn.fnamemodify(vim.fn.fnamemodify(component.dir, ":h"), ":.")
    table.insert(preview_lines, "    " .. parent_rel .. "/" .. old_name .. "/  ->  " .. parent_rel .. "/" .. new_kebab .. "/")
  end
  table.insert(preview_lines, "")
  table.insert(preview_lines, "  [Tab] next field  [Enter] rename  [Esc] cancel")

  -- Create 3 Input components
  local input_name = Input({
    border = {
      style = "rounded",
      text = { top = " Name ", top_align = "left" },
    },
    win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
  }, {
    default_value = new_pascal,
    on_change = function(val) values.name = val end,
  })

  local input_selector = Input({
    border = {
      style = "rounded",
      text = { top = " Selector ", top_align = "left" },
    },
    win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
  }, {
    default_value = new_selector,
    on_change = function(val) values.selector = val end,
  })

  local input_class = Input({
    border = {
      style = "rounded",
      text = { top = " Class ", top_align = "left" },
    },
    win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
  }, {
    default_value = new_class,
    on_change = function(val) values.class = val end,
  })

  -- Read-only preview popup
  local preview = Popup({
    border = {
      style = "rounded",
      text = { top = " Preview ", top_align = "left" },
    },
    win_options = { winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
  })

  -- Layout: stack vertically
  local layout = Layout(
    {
      position = "50%",
      size = {
        width = 70,
        height = 3 * 3 + #preview_lines + 2, -- 3 inputs * 3 rows each + preview
      },
      relative = "editor",
    },
    Layout.Box({
      Layout.Box(input_name, { size = 3 }),
      Layout.Box(input_selector, { size = 3 }),
      Layout.Box(input_class, { size = 3 }),
      Layout.Box(preview, { grow = 1 }),
    }, { dir = "col" })
  )

  layout:mount()

  -- Set preview content (read-only)
  vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, preview_lines)
  vim.bo[preview.bufnr].modifiable = false

  -- Track inputs for Tab navigation
  local inputs = { input_name, input_selector, input_class }
  local current_idx = 1

  --- Focus a specific input by index
  local function focus(idx)
    current_idx = idx
    vim.api.nvim_set_current_win(inputs[idx].winid)
    vim.cmd("startinsert!")
  end

  --- Focus the next input
  local function focus_next()
    focus((current_idx % #inputs) + 1)
  end

  --- Focus the previous input
  local function focus_prev()
    focus(((current_idx - 2) % #inputs) + 1)
  end

  --- Unmount everything
  local function close()
    layout:unmount()
  end

  --- Confirm and execute
  local function confirm()
    local name_val = values.name or ""
    local selector_val = values.selector or ""
    local class_val = values.class or ""

    close()

    -- Derive kebab from the name field
    local edited_kebab = utils.normalize_to_kebab(name_val)

    if edited_kebab == old_name then
      log("New name is the same as the current name -- nothing to do", "warn")
      return
    end

    -- Validate
    if not edited_kebab:match("^[a-z][a-z0-9%-]*[a-z0-9]$") and not edited_kebab:match("^[a-z][a-z0-9]*$") then
      log("Invalid name: '" .. name_val .. "' (resolves to '" .. edited_kebab .. "')", "error")
      return
    end

    if M.config.dry_run then
      log("DRY RUN -- no changes made", "warn")
      log("  Name: " .. edited_kebab, "info")
      log("  Selector: " .. selector_val, "info")
      log("  Class: " .. class_val, "info")
      return
    end

    execute_rename(component, edited_kebab, selector_val, class_val, project_root)
    log(string.format("Renamed '%s' -> '%s'", old_name, edited_kebab), "info")
  end

  -- Set keymaps on each input
  for _, inp in ipairs(inputs) do
    -- Tab -> next field
    inp:map("i", "<Tab>", focus_next, { noremap = true })
    inp:map("n", "<Tab>", focus_next, { noremap = true })
    -- Shift-Tab -> previous field
    inp:map("i", "<S-Tab>", focus_prev, { noremap = true })
    inp:map("n", "<S-Tab>", focus_prev, { noremap = true })
    -- Enter -> confirm (override nui.input's default submit)
    inp:map("i", "<CR>", confirm, { noremap = true })
    inp:map("n", "<CR>", confirm, { noremap = true })
    -- Esc -> cancel
    inp:map("n", "<Esc>", close, { noremap = true })
    inp:map("i", "<Esc>", function()
      vim.cmd("stopinsert")
      close()
    end, { noremap = true })
  end

  -- Start focused on the Name input in insert mode
  focus(1)
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------

--- Main rename function. Prompts for the new name, then opens the form dialog.
function M.rename()
  -- Detect current component first so we can fail fast
  local filepath = vim.fn.expand("%:p")
  local component = utils.detect_component(filepath)
  if not component then
    log("Current file is not part of an Angular component", "error")
    log("Open a *.component.ts/html/scss file first", "error")
    return
  end

  local project_root = utils.find_angular_root(component.dir)
  if not project_root then
    log("Could not find angular.json -- are you in an Angular project?", "error")
    return
  end

  log(string.format("Angular project root: %s", vim.fn.fnamemodify(project_root, ":.")), "debug")

  -- Prompt for the new name, then open the form
  vim.ui.input({ prompt = "New component name: " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    local new_kebab = utils.normalize_to_kebab(vim.trim(input))
    if new_kebab == component.name then
      log("New name is the same as the current name", "warn")
      return
    end
    -- Schedule to avoid issues with vim.ui.input callback context
    vim.schedule(function()
      open_dialog(component, new_kebab, project_root)
    end)
  end)
end

--- Setup function for plugin configuration
---@param opts AngularRenameConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  vim.api.nvim_create_user_command("AngularRenameComponent", function()
    M.rename()
  end, {
    nargs = 0,
    desc = "Rename an Angular component and all its associated files and references",
  })
end

return M
