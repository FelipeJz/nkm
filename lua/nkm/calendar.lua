local api = vim.api
local M = {}

local state = {
  win = nil,
  buf = nil,
  month = os.date("*t").month,
  year = os.date("*t").year,
  selected = os.date("*t").day, -- Default to today
}

local days = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

local function get_days_in_month(month, year)
  return os.date("*t", os.time{year=year, month=month+1, day=0}).day
end

local function get_start_day(month, year)
  return os.date("*t", os.time{year=year, month=month, day=1}).wday
end

local function center(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", pad) .. text
end

local function render_calendar()
  if not api.nvim_buf_is_valid(state.buf) then return end
  local lines = {}

  local title = os.date("%B %Y", os.time{year=state.year, month=state.month, day=1})
  table.insert(lines, center(title, 20))
  table.insert(lines, table.concat(days, " "))

  local start = get_start_day(state.month, state.year)
  local total = get_days_in_month(state.month, state.year)

  local row = {}
  for i = 1, start - 1 do table.insert(row, "  ") end

  for day = 1, total do
    -- Mark the selected day
    local display_day = string.format("%2d", day)
    if day == state.selected then
      display_day = "[" .. display_day .. "]"  -- Highlight selected day
    end
    table.insert(row, display_day)
    
    if #row == 7 then
      table.insert(lines, table.concat(row, " "))
      row = {}
    end
  end
  if #row > 0 then table.insert(lines, table.concat(row, " ")) end

  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
end

function M.open(callback)
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end

  state.buf = api.nvim_create_buf(false, true)
  render_calendar()

  local width, height = 24, 10
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  state.win = api.nvim_open_win(state.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  api.nvim_buf_set_keymap(state.buf, "n", "q", "<cmd>bd!<CR>", { nowait=true, noremap=true, silent=true })

  api.nvim_buf_set_keymap(state.buf, "n", "n", "", {
    callback = function()
      state.month = state.month + 1
      if state.month > 12 then
        state.month = 1
        state.year = state.year + 1
      end
      render_calendar()
    end,
    noremap = true,
    silent = true,
  })

  api.nvim_buf_set_keymap(state.buf, "n", "p", "", {
    callback = function()
      state.month = state.month - 1
      if state.month < 1 then
        state.month = 12
        state.year = state.year - 1
      end
      render_calendar()
    end,
    noremap = true,
    silent = true,
  })

  -- Navigation for day selection
  api.nvim_buf_set_keymap(state.buf, "n", "<CR>", "", {
    callback = function()
      local date = string.format("%04d-%02d-%02d", state.year, state.month, state.selected)
      callback(date)
      api.nvim_win_close(state.win, true)
    end,
    noremap = true,
    silent = true,
  })

  -- Handle day selection
  for day = 1, get_days_in_month(state.month, state.year) do
    api.nvim_buf_set_keymap(state.buf, "n", tostring(day), "", {
      callback = function()
        print(day)
        state.selected = day
        render_calendar()
      end,
      noremap = true,
      silent = true,
    })
  end
end

return M
