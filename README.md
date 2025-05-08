# NKM

Neovim Knowledge Management that uses .md files to display information inline like tasks, tables and generate templates using custom .lua scripts.

![screenshot](https://github.com/FelipeJz/nkm/blob/master/examples/screenshot.jpg)

## Installation

Using Lazy

```lua
{
  "felipejz/nkm",
  config = function()
    require("nkm")
    local nkm = require("nkm.core")

    nkm.setup({
      task_statuses = {
        { symbol = " ", label = "todo", emoji = "🟥" },
        { symbol = "x", label = "done", emoji = "✅" },
        { symbol = "/", label = "in progress", emoji = "🟦" },
      },
      root_path = "~/nkm",
      template_path = "~/nkm/templates/daily_template.md",
      daily_folder = "~/nkm/journal",
      state_path = "~/nkm/state/state.md",
      use_task_id = true
    })

    -- Navigation
    vim.keymap.set("n", "<leader>gj", function() require("nkm.core").generate_daily() end,
      { noremap = true, silent = true })

    vim.keymap.set("n", "<leader>gs", function() require("nkm.calendar").open() end,
      { noremap = true, silent = true })

    vim.keymap.set("n", "<leader>gg", function() require("nkm.core").go_to_link("~/nkm/dashboard.md") end,
      { noremap = true, silent = true })

    vim.keymap.set("n", "<leader>gq",
      function()
        require("nkm.core").generate_template("~/nkm/_templates/quests.md", "~/nkm/quests",
          { { "name", nil }, { "status", nil } })
      end,
      { noremap = true, silent = true })

    -- Link management
    vim.api.nvim_set_keymap('n', '<leader>gd', ':lua require("nkm.core").go_to_link()<CR>',
      { noremap = true, silent = true })

    -- Task management
    vim.keymap.set("n", "<leader>gtt", function() require("nkm.core").toggle_task() end,
      { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>gs", function() require("nkm.core").toggle_task(nil, nil, "s") end,
      { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>gts", function() require("nkm.core").update_task("s") end,
      { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>gti", function() require("nkm.core").update_task("/") end,
      { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>gtd", function() require("nkm.core").update_task("x") end,
      { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>gtu", function() require("nkm.core").update_task(" ") end,
      { noremap = true, silent = true })
  end,
}
```

## To start

1. Copy the example folder to ~/ and rename it to nkm
2. Explore the files and example scripts

## Todo list

- [ ] Format for tasks on scripts
- [ ] Finish schedule tasks and calendar
- [ ] Fix script line wrap overflow
- [ ] Fix diseapering lines
- [ ] Toggle script view
- [ ] Create frontmatter search util
