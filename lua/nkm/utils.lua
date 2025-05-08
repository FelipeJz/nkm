local M = {}
local uv = vim.loop

function M.expand_home(path)
  local home = os.getenv("HOME")
  if not home then error("HOME environment variable not set") end
  return path:gsub("^~", home)
end

-- Reads frontmatter arguments in the specified file

function M.read_frontmatter(filepath)
  local file = io.open(M.expand_home(filepath), "r")
  if not file then return nil, "cannot open file: " .. filepath end

  local inside = false
  local frontmatter = {}
  local content = ""
  local after_frontmatter = false

  for line in file:lines() do
    if line:match("^%-%-%-%s*$") then
      if not inside then
        inside = true
      elseif inside then
        after_frontmatter = true
      end
    elseif inside and not after_frontmatter then
      -- Capture key-value pairs
      local key, value = line:match("^([%w-_]+):%s*(.+)$")
      if key and value then
        frontmatter[key] = value
      end
    elseif after_frontmatter then
      -- Append the rest to content
      content = content .. line .. "\n"
    end
  end

  file:close()
  return frontmatter, content
end

-- Updates frontmatter with the provided key-value pairs
function M.update_frontmatter(filepath, updates)
  -- Read the current frontmatter
  local frontmatter = M.read_frontmatter(filepath)
  if not frontmatter then return nil end


  -- Rebuild the frontmatter section
  local new_frontmatter = "---\n"
  for key, value in pairs(frontmatter) do
    if updates[1] == key then
      new_frontmatter = new_frontmatter .. key .. ": " .. updates[2] .. "\n"
    else
      new_frontmatter = new_frontmatter .. key .. ": " .. value .. "\n"
    end
  end
  new_frontmatter = new_frontmatter .. "---\n"

  -- Read the rest of the file after the frontmatter
  local file = io.open(M.expand_home(filepath), "r")
  if not file then return nil, "cannot open file: " .. filepath end

  local content = ""
  local inside_frontmatter = false

  for line in file:lines() do
    if line:match("^%-%-%-%s*$") then
      inside_frontmatter = not inside_frontmatter -- toggle start/end
    elseif inside_frontmatter then
      local key, value = line:match("^([%w-_]+):%s*(.+)$")
      if key and value then
        frontmatter[key] = value
      end
    else
      content = content .. line .. "\n"
    end
  end

  file:close()

  -- Write the updated content back to the file
  local file_save = io.open(M.expand_home(filepath), "w")
  if not file_save then return nil, "cannot open file for writing: " .. filepath end
  file_save:write(new_frontmatter .. content)
  file_save:close()

  return true
end

-- Function to get all files in a directory
function M.get_files_in_directory(directory)
  local files = {}
  local handle = io.popen('find "' .. directory .. '" -type f -name "*.md"')

  if handle then
    for file in handle:lines() do
      table.insert(files, file)
    end
    handle:close()
  end

  return files
end

function M.search_tasks_in_file(file, status, tags, label, return_type)
  return_type = return_type or "desc"

  local tasks = {}

  if status == "_" then status = " " end

  local file_content = {}
  local file_handle = io.open(M.expand_home(file), "r")
  if file_handle then
    for line in file_handle:lines() do
      table.insert(file_content, line)
    end
    file_handle:close()
  end

  for i, line in ipairs(file_content) do
    local task_status, task_desc = line:match("^%s*%- %[(.)%] (.+)$")

    if task_status and (task_status == status or not status) then
      local found = not tags or #tags == 0

      if tags and #tags > 0 then
        for _, t in ipairs(tags) do
          if task_desc:find("#" .. t) then
            found = true
            break
          end
        end
      end

      if found then
        if return_type == "desc" then
          table.insert(tasks, (label or "") .. " " .. task_desc)
        else
          table.insert(tasks, {
            row = i,
            desc = task_desc,
            status = task_status,
            tags = tags,
          })
        end
      end
    end
  end

  return tasks
end

function M.scan_dir(dir, files)
  files = files or {}
  dir = M.expand_home(dir)

  local fs = uv.fs_scandir(dir)
  if not fs then return files end

  while true do
    local name, type = uv.fs_scandir_next(fs)
    if not name then break end
    local path = dir .. "/" .. name
    if type == "directory" then
      M.scan_dir(path, files)
    elseif type == "file" then
      files[#files + 1] = path
    end
  end

  return files
end

function M.format_table(matrix, opts)
  opts = opts or {}
  if type(matrix) ~= "table" then
    return {}
  end

  -- Find max width per column, using strwidth for correct character width
  local max_widths = {}
  for _, row in ipairs(matrix) do
    for col_idx, item in ipairs(row) do
      local str = tostring(item)
      local width = vim.fn.strwidth(str) -- Correct width calculation
      max_widths[col_idx] = math.max(max_widths[col_idx] or 0, width)
    end
  end

  local result = {}

  for row_idx, row in ipairs(matrix) do
    local formatted_row = {}

    for col_idx, item in ipairs(row) do
      local str = tostring(item)
      local width = vim.fn.strwidth(str)
      local padding = string.rep(" ", max_widths[col_idx] - width)
      table.insert(formatted_row, str .. padding)
    end

    table.insert(result, table.concat(formatted_row, " | "))

    -- After first row, optionally insert a separator
    if opts.separator and row_idx == 1 then
      local separator_row = {}
      for _, width in ipairs(max_widths) do
        table.insert(separator_row, string.rep("-", width))
      end
      table.insert(result, table.concat(separator_row, " | "))
    end
  end

  return result
end

function M.next_available_filename(filepath)
  local dir, filename, ext = filepath:match("^(.-)([^/]+)%.([^%.]+)$")
  if not dir then
    error("Invalid file path: " .. filepath)
  end

  local name = filename
  local number = 1

  -- Find existing files
  local function exists(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == "file"
  end

  local new_filepath = dir .. name .. "." .. ext
  while exists(new_filepath) do
    new_filepath = dir .. name .. "_" .. number .. "." .. ext
    number = number + 1
  end

  return new_filepath
end

function M.tableToString(tbl)
  local function serialize(val)
    if type(val) == "table" then
      local result = "{"
      for k, v in pairs(val) do
        result = result .. "[" .. serialize(k) .. "] = " .. serialize(v) .. ", "
      end
      result = result:sub(1, -3) -- Remove the last comma and space
      result = result .. "}"
      return result
    else
      return tostring(val)
    end
  end
  return serialize(tbl)
end

function M.is_buffer_open(buf_id)
  local buffers = vim.api.nvim_list_bufs()

  for _, id in ipairs(buffers) do
    if id == buf_id then
      return true
    end
  end
  return false
end

function M.is_buffer_open_by_path(file_path)
  local buffers = vim.api.nvim_list_bufs()

  for _, buf_id in ipairs(buffers) do
    local buf_path = vim.api.nvim_buf_get_name(buf_id)
    if buf_path == file_path then
      return buf_id
    end
  end
  return false
end

function M.has_extension(filename)
  return filename:match("%.[^%.]+$") ~= nil
end

function M.open_side_float()
  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.3)
  local height = math.floor(vim.o.lines * 0.8)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = vim.o.columns - width - 2, -- 2 for a bit of padding
    style = "minimal",
    border = "rounded",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Floating window on the side",
    "You can add anything here",
  })

  vim.api.nvim_open_win(buf, false, opts)
end

function M.get_current_file()
  return vim.api.nvim_buf_get_name(0)
end

return M
