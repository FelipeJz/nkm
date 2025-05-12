local utils = require("nkm.utils")
local calendar = require("nkm.calendar")

local M = {}

M.config = {
  use_task_id = true,
  task_statuses = {
    { symbol = " ", label = "todo", emoji = "🟥" },
    { symbol = "x", label = "done", emoji = "✅" },
    { symbol = "/", label = "in progress", emoji = "🟦" },
  },
  root_path = "~/nkm",
  template_path = "~/nkm/_templates/daily_template.md",
  daily_folder = "~/nkm/journal",
  state_path = "~/nkm/_state/state.md",
  colors = {
    script = "#B3BCE6",
    underline = "#88C0D0"
  }
}

local DATE_MARKERS = {
  created = {
    match = "@created%(([%d%-]+)%)",
    strip = "@created%([^)]+%)"
  },
  done = {
    match = "@done%(([%d%-]+)%)",
    strip = "@done%([^)]+%)"
  },
  scheduled = {
    match = "@scheduled%(([%d%-]+)%)",
    strip = "@scheduled%([^)]+%)"
  },
  id = {
    match = "@(%d+)",
    strip = "@%d+"
  }
}

M.tasks = {}

local ns_id = vim.api.nvim_create_namespace("nkm_overlay")

local script_pattern = "{{%s*(%b[])%s*}}"
local link_pattern = "%[%[(.-)%]%]"

-- Setup highlight groups
vim.api.nvim_set_hl(0, "NkmLinkInactive", { underline = true, fg = M.config.colors.underline })

function M.update_virtual_text()
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]

  if vim.bo.filetype ~= "markdown" then return end

  vim.api.nvim_buf_clear_namespace(buffer, ns_id, 0, -1)
  local all_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  for line_number, line_text in ipairs(all_lines) do
    local is_cursor_line = (line_number == cursor_line)

    -- Skip the current cursor line
    if is_cursor_line then goto continue end

    -- Normal lines (task emojis, links, etc.)
    local virtual_text = {}
    local current_col = 1

    -- Add task emoji at beginning if line is a task
    local task_symbol = line_text:match("^%s*%- %[(.)%] ")
    if task_symbol then
      for _, status in ipairs(M.config.task_statuses) do
        if status.symbol == task_symbol then
          table.insert(virtual_text, { status.emoji .. " ", "Normal" })
          current_col = line_text:find("]") + 2
          break
        end
      end
    end

    -- Check if the line is a markdown heading
    local is_heading = line_text:match("^#+") -- Matches any heading level (#, ##, ###, etc.)
    local heading_level = is_heading and line_text:match("^#*") or nil

    if is_heading then
      if is_cursor_line then
        -- Show the full heading if the cursor is on it
        table.insert(virtual_text, { line_text, "MarkdownHeading" })
      else
        -- If cursor is not on the heading, hide the #
        local heading_content = line_text:sub(#heading_level + 1):match("^%s*(.*)") -- Remove the # and leading spaces
        local heading_highlight = "MarkdownH" ..
            heading_level:len()

        table.insert(virtual_text, { heading_content, heading_highlight })

        -- Add padding to match the real line width
        local real_width = vim.fn.strdisplaywidth(line_text)
        local virtual_width = vim.fn.strdisplaywidth(heading_content)

        if virtual_width < real_width then
          heading_content = heading_content .. string.rep(" ", real_width - virtual_width)
        end
      end
    else
      -- Non-heading lines
      while current_col <= #line_text do
        local script_start, script_end, json_body = line_text:find(script_pattern)
        local link_start, link_end, link_content = line_text:find(link_pattern, current_col)

        local match_start, match_end, match_type = nil, nil, nil

        if script_start and (not link_start or script_start < link_start) then
          match_start, match_end, match_type = script_start, script_end, "script"
        elseif link_start then
          match_start, match_end, match_type = link_start, link_end, "link"
        end

        local function format_tasks(tbl, text)
          local created_marker   = text:match(DATE_MARKERS.created.match)
          local done_marker      = text:match(DATE_MARKERS.done.match)
          local scheduled_marker = text:match(DATE_MARKERS.scheduled.match)
          local id_marker        = text:match(DATE_MARKERS.id.match)

          local start_text       = text

          -- Detect and highlight the task markers (@created, @done, @scheduled)
          start_text             = start_text
              :gsub(DATE_MARKERS.created.strip, "")
              :gsub(DATE_MARKERS.done.strip, "")
              :gsub(DATE_MARKERS.scheduled.strip, "")
              :gsub(DATE_MARKERS.id.strip, "")

          -- Remove consecutive spaces left behind at the end of the line
          start_text             = start_text:gsub("%s+$", "")

          table.insert(tbl, { start_text:sub(current_col), "Normal" })

          if created_marker then
            table.insert(tbl, { " 📅" .. created_marker, "TaskMarkerCreated" })
          end

          if done_marker then
            table.insert(tbl, { " ✅" .. done_marker, "TaskMarkerDone" })
          end

          if scheduled_marker then
            table.insert(tbl, { " ⏳" .. scheduled_marker, "TaskMarkerScheduled" })
          end

          if id_marker then
            table.insert(tbl, { " @" .. id_marker, "TaskMarkerID" })
          end
        end

        if not match_start then
          format_tasks(virtual_text, line_text)
          break
        end

        if match_start > current_col then
          table.insert(virtual_text, { line_text:sub(current_col, match_start - 1), "Normal" })
        end

        -- Gets script text
        if match_type == "script" then
          local _, decoded = pcall(vim.fn.json_decode, json_body)
          local result = M.run_script(decoded[1], decoded[2] or {})

          -- Displays the first line of the script as a single overlay
          if #result > 0 then
            local display_text = result[1]

            -- Pad display_text to match real line width
            local real_width = vim.fn.strdisplaywidth(line_text)
            local virtual_width = vim.fn.strdisplaywidth(display_text)

            if virtual_width < real_width then
              display_text = display_text .. string.rep(" ", real_width - virtual_width)
            end

            local display_table = {}
            format_tasks(display_table, display_text)

            vim.api.nvim_buf_set_extmark(buffer, ns_id, line_number - 1, 0, {
              virt_text = display_table,
              virt_text_pos = "overlay",
              hl_mode = "combine",
            })
          end

          -- Displays the rest of the script in virtual lines
          if #result > 1 then
            local virt_lines = {}
            for i = 2, #result do
              local display_table = {}
              format_tasks(display_table, result[i])
              table.insert(virt_lines, display_table)
            end

            vim.api.nvim_buf_set_extmark(buffer, ns_id, line_number - 1, 0, {
              virt_lines = virt_lines,
              virt_lines_above = false,
              hl_mode = "combine",
            })
          end
        elseif match_type == "link" then
          local target, label = link_content:match("^(.-)|(.+)$")
          target = target or link_content
          label = label or link_content
          local display_text = label or target
          table.insert(virtual_text, { display_text, "NkmLinkInactive" })
        end

        current_col = match_end + 1
      end
    end

    -- Fill the line with spaces to hide script content
    local virtual_width = 0
    for _, chunk in ipairs(virtual_text) do
      virtual_width = virtual_width + vim.fn.strdisplaywidth(chunk[1])
    end

    local real_width = vim.fn.strdisplaywidth(line_text)
    if virtual_width < real_width then
      table.insert(virtual_text, { string.rep(" ", real_width - virtual_width), "Normal" })
    end
    --

    vim.api.nvim_buf_set_extmark(buffer, ns_id, line_number - 1, 0, {
      virt_text = virtual_text,
      virt_text_pos = "overlay",
      hl_mode = "combine",
    })

    ::continue::
  end
end

-- Runs external scripts
function M.run_script(script_path, script_call)
  local args = script_call or {}

  local full_path = vim.fn.expand(script_path)
  local source_file = vim.api.nvim_buf_get_name(0)

  local chunk, err = loadfile(full_path)
  if not chunk then return { "<load error: " .. err .. ">" } end

  local ok_chunk, result = pcall(chunk)
  if not ok_chunk then return { "<runtime error: " .. result .. ">" } end

  if type(result) == "function" then
    local ok2, func_result = pcall(result, source_file, args)
    if not ok2 then return { "<runtime error: " .. func_result .. ">" } end
    if type(func_result) ~= "table" then return { "<non-table return>" } end
    return func_result
  elseif type(result) == "table" then
    return result
  else
    return { "<invalid script return>" }
  end
end

function M.go_to_link(direct_link)
  if direct_link then
    vim.cmd("edit " .. direct_link)
  end

  local line = vim.api.nvim_get_current_line()
  local link_start, link_end = line:find(link_pattern)

  if link_start then
    local link_text = line:sub(link_start + 2, link_end - 2)
    local target, _ = link_text:match("^(.-)|(.+)$")
    local file_path = vim.fn.expand(target)

    if not target then
      target = target or link_text
      file_path = vim.fn.expand(M.config.root_path .. "/" .. target .. ".md")
    end

    if vim.fn.filereadable(file_path) == 1 then
      vim.cmd("edit " .. file_path)
    else
      -- Create and open the file
      local fd = io.open(file_path, "w")
      if fd then
        fd:close()
        vim.cmd("edit " .. file_path)
      else
        print("Failed to create file: " .. file_path)
      end
    end
  end
end

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

function M.toggle_task(remote_file_path, remote_row, remote_status)
  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local statuses = M.config.task_statuses
  local task_pattern = "^%s*%- %[(.)%] "

  local current_symbol = line:match(task_pattern)

  local function manage_counter()
    local frontmatter = utils.read_frontmatter(M.config.state_path)

    if frontmatter == nil then
      return nil
    end

    local counter = frontmatter["task_id"]
    utils.update_frontmatter(M.config.state_path, { "task_id", counter + 1 })

    return counter
  end

  -- Create a new task if not found
  if not current_symbol and not remote_file_path then
    local new_task = "- [" .. statuses[1].symbol .. "]  @created(" .. os.date("%Y-%m-%d") .. ")"

    if M.config.use_task_id then
      local counter = manage_counter()
      new_task = new_task .. (counter and (" @" .. counter) or "")
    end

    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_task })
    vim.api.nvim_win_set_cursor(0, { row, 6 })
    vim.cmd("startinsert")
    M.update_virtual_text()
    return
  end

  local symbols = {}
  for i, status in ipairs(statuses) do
    symbols[status.symbol] = i
  end

  local current_index = symbols[current_symbol] or 0
  local next_index = (current_index % #statuses) + 1
  local next_symbol = remote_status or statuses[next_index].symbol

  -- Remote buffer update
  if remote_file_path and remote_row then
    -- Create a new buffer
    local is_open = utils.is_buffer_open_by_path(remote_file_path)
    local buf_id = vim.api.nvim_create_buf(false, true)

    -- Read the file into the buffer
    vim.api.nvim_buf_set_lines(buf_id, 0, 0, false, vim.fn.readfile(remote_file_path))

    -- Now fetch the line from the buffer
    local remote_line = vim.api.nvim_buf_get_lines(buf_id, remote_row - 1, remote_row, false)[1]

    if not remote_line then
      print("Error: Could not retrieve line " .. remote_row)
      return
    end

    -- For schedule dates
    local new_line = remote_line
    if next_symbol == "s" then
      remote_line = remote_line
          :gsub(DATE_MARKERS.scheduled.strip, "")

      remote_line = remote_line:gsub("%s+$", "")
      calendar.open(function(date)
        if not date then return end
        remote_line = remote_line .. " " .. "@scheduled(" .. date .. ")"
      end)
    else
      new_line = remote_line:gsub(task_pattern, string.format("- [%s] ", next_symbol), 1)
    end

    local current_buf = is_open or buf_id

    -- Setup the date markers
    -- Remove done marker status change means is not done anymore
    new_line          = new_line
        :gsub(DATE_MARKERS.done.strip, "")

    if next_symbol == "x" then
      new_line = new_line:gsub("%s+$", "")
      new_line = new_line .. " " .. "@done(" .. os.date("%Y-%m-%d") .. ")"
    end

    -- Remove the 'buftype' setting that prevents writing
    vim.api.nvim_buf_set_option(current_buf, 'buftype', '')

    -- Set the buffer name (file path)
    vim.api.nvim_buf_set_name(current_buf, remote_file_path)

    -- Update the line in the buffer
    vim.api.nvim_buf_set_lines(current_buf, remote_row - 1, remote_row, false, { new_line })

    -- Write the buffer back to the file
    vim.api.nvim_buf_call(current_buf, function()
      vim.cmd("write!") -- Force write the buffer to the file
    end)

    -- Delete the buffer after use if not open
    if not is_open then
      vim.api.nvim_buf_delete(buf_id, { force = true })
    end

    M.update_virtual_text()
    return
  end

  -- Local update
  local new_line = line
  if next_symbol == "s" then
    new_line = new_line
        :gsub(DATE_MARKERS.scheduled.strip, "")

    new_line = new_line:gsub("%s+$", "")
    calendar.open(function(date)
      vim.schedule(function()
        if not date then return end
        new_line = new_line .. " " .. "@scheduled(" .. date .. ")"
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
      end)
    end)
  else
    new_line = line:gsub(task_pattern, string.format("- [%s] ", next_symbol), 1)
    new_line = new_line
        :gsub(DATE_MARKERS.done.strip, "")
    if next_symbol == "x" then
      new_line = new_line:gsub("%s+$", "")
      new_line = new_line .. " " .. "@done(" .. os.date("%Y-%m-%d") .. ")"
    end
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  end
end

function M.update_task(new_status)
  local task_id = vim.fn.input("Enter task_id: ")
  local files = utils.scan_dir(M.config.root_path)

  for _, file in ipairs(files) do
    local file_tasks = utils.search_tasks_in_file(file, nil, nil, nil, "data")
    if #file_tasks then
      for _, task in ipairs(file_tasks) do
        if string.find(task.desc, task_id) then
          M.toggle_task(file, task.row, new_status)
          break
        end
      end
    end
  end
end

function M.generate_daily()
  local template_path = vim.fn.expand(M.config.template_path)
  local daily_folder = vim.fn.expand(M.config.daily_folder)

  local daily_file_name = os.date("%Y-%m-%d") .. ".md"
  local daily_path = daily_folder .. "/" .. daily_file_name

  local date_today = os.date("%B %d, %Y")

  if M.config.use_task_id then
    local frontmatter = utils.read_frontmatter(M.config.state_path)

    if frontmatter == nil then
      return nil
    end

    local next_id = frontmatter["task_id"]

    local last_id = M.generate_template(template_path, daily_path, { { "date", date_today } }, "open",
      { "@", next_id or 1, "append" })

    if last_id then
      utils.update_frontmatter(M.config.state_path, { "task_id", last_id })
    end
  else
    M.generate_template(template_path, daily_path, { { "date", date_today } }, "open")
  end
end

-- Generates a template
-- @param string template_path The template file
-- @param string destination_path Where the template will be generated
-- @param {key, value}[] replacements Data replaced in the template
-- @param "open" or "replace" or "number" if_exists Determines what to do if file exists
-- @param {key, first_index, "append" or "replace"} auto_index Generates auto index
-- @return void
function M.generate_template(template_path, destination_path, replacements, if_exists, auto_index)
  if_exists = if_exists or "open"

  template_path = vim.fn.expand(template_path)
  destination_path = vim.fn.expand(destination_path)

  -- If destination file already exists, handle according to if_exists
  if not utils.has_extension(destination_path) then
    destination_path = destination_path .. "/" .. vim.fn.input("Enter file name: ") .. ".md"
  end

  table.insert(replacements, { "destination_path", destination_path })

  if vim.fn.filereadable(destination_path) == 1 then
    if if_exists == "open" then
      vim.cmd("edit " .. destination_path)
      return
    end

    if if_exists == "number" then
      destination_path = utils.next_available_filename(destination_path)
    end
  end

  -- If auto_index is provided, handle the index before file generation
  local current_index = auto_index and auto_index[2] or 1
  local symbol = auto_index and auto_index[1] or "@"
  local action = auto_index and auto_index[3] or "replace"

  -- Read the existing file content if exists, to find and update the index
  if vim.fn.filereadable(destination_path) == 1 then
    local content = table.concat(vim.fn.readfile(destination_path), "\n")
    -- Look for the symbol and extract its index if exists
    local index_match = content:match("{" .. symbol .. "}: (%d+)")
    if index_match then
      current_index = tonumber(index_match) or current_index
    end
  end

  -- Apply the auto_index replacement if needed
  if auto_index then
    replacements = replacements or {}
    table.insert(replacements, { symbol, tostring(current_index) })
  end

  -- If template exists, create the file
  if vim.fn.filereadable(template_path) == 1 then
    local template = table.concat(vim.fn.readfile(template_path), "\n")

    -- Apply any other replacements to the template
    if replacements then
      for _, pair in ipairs(replacements) do
        local key = pair[1]
        local value = pair[2] or vim.fn.input("Enter " .. (pair[1] or "") .. ": ")
        -- Replace placeholders like {key} with the provided value
        template = template:gsub("{" .. key .. "}", value)
      end
    end

    -- Handle symbol replacement for auto-index
    template = template:gsub(symbol, function()
      local replace_value
      if action == "append" then
        -- Append the index to the symbol (e.g., @1, @2, @3)
        replace_value = symbol .. tostring(current_index)
      elseif action == "replace" then
        -- Replace the symbol with the index (e.g., 1, 2, 3)
        replace_value = tostring(current_index)
      end
      current_index = current_index + 1
      return replace_value
    end)

    -- Make sure the destination folder exists
    vim.fn.mkdir(vim.fn.fnamemodify(destination_path, ":h"), "p")

    vim.fn.writefile(vim.split(template, "\n"), destination_path)
    vim.cmd("edit " .. destination_path)
    return current_index
  else
    print("Template not found: " .. template_path)
  end
end

return M
