local M = {}

--- Convert kebab-case to PascalCase
--- e.g. "foo-bar" -> "FooBar"
---@param str string
---@return string
function M.kebab_to_pascal(str)
  return str:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end):gsub("-", "")
end

--- Convert PascalCase to kebab-case
--- e.g. "FooBar" -> "foo-bar"
---@param str string
---@return string
function M.pascal_to_kebab(str)
  local result = str:gsub("(%u)", function(c)
    return "-" .. c:lower()
  end)
  if result:sub(1, 1) == "-" then
    result = result:sub(2)
  end
  return result
end

--- Normalize any input format to kebab-case
--- Accepts: PascalCase, camelCase, kebab-case, snake_case
---@param str string
---@return string
function M.normalize_to_kebab(str)
  -- If it contains dashes, assume kebab-case already
  if str:match("-") then
    return str:lower()
  end
  -- If it contains underscores, convert snake_case
  if str:match("_") then
    return str:gsub("_", "-"):lower()
  end
  -- Otherwise assume PascalCase or camelCase
  return M.pascal_to_kebab(str)
end

--- Check if a file exists
---@param path string
---@return boolean
function M.file_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

--- Read entire file contents
---@param path string
---@return string|nil
function M.read_file(path)
  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then return nil end
  local stat = vim.loop.fs_fstat(fd)
  if not stat then
    vim.loop.fs_close(fd)
    return nil
  end
  local data = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)
  return data
end

--- Write contents to a file
---@param path string
---@param content string
---@return boolean
function M.write_file(path, content)
  local fd = vim.loop.fs_open(path, "w", 438)
  if not fd then return false end
  vim.loop.fs_write(fd, content, 0)
  vim.loop.fs_close(fd)
  return true
end

--- Find all files matching a glob pattern relative to root
---@param root string
---@param pattern string
---@return string[]
function M.find_files(root, pattern)
  local matches = vim.fn.glob(root .. "/" .. pattern, false, true)
  return matches or {}
end

--- Escape a string for use in Lua patterns
---@param str string
---@return string
function M.escape_pattern(str)
  return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

--- Detect Angular project root by finding angular.json
---@param start_path string
---@return string|nil
function M.find_angular_root(start_path)
  local markers = { "angular.json", ".angular.json", "nx.json" }
  local path = start_path
  while path and path ~= "/" do
    for _, marker in ipairs(markers) do
      if M.file_exists(path .. "/" .. marker) then
        return path
      end
    end
    path = vim.fn.fnamemodify(path, ":h")
  end
  return nil
end

--- Detect component info from a file path
---@param filepath string
---@return table|nil
function M.detect_component(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  local filename = vim.fn.fnamemodify(filepath, ":t")

  local name = filename:match("^(.+)%.component%.[^.]+$")
  if not name then return nil end

  local extensions = {}
  local possible = { "ts", "html", "scss", "css", "less", "spec.ts" }
  for _, ext in ipairs(possible) do
    local test_path = dir .. "/" .. name .. ".component." .. ext
    if M.file_exists(test_path) then
      table.insert(extensions, ext)
    end
  end

  if #extensions == 0 then return nil end

  -- Detect selector prefix from .component.ts
  local prefix = "app"
  local ts_path = dir .. "/" .. name .. ".component.ts"
  if M.file_exists(ts_path) then
    local content = M.read_file(ts_path)
    if content then
      local selector = content:match("selector:%s*['\"]([^'\"]+)['\"]")
      if selector then
        local p = selector:match("^([^-]+)-")
        if p then prefix = p end
      end
    end
  end

  return {
    name = name,
    dir = dir,
    prefix = prefix,
    extensions = extensions,
  }
end

return M
