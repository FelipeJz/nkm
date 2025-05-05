local core = require("nkm.core")

-- Setup autocommand to refresh on cursor move
vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
  callback = function()
    core.update_virtual_text()
  end,
})

-- Better links
vim.cmd([[
    augroup NkmConceal
      autocmd!
      autocmd FileType markdown syntax match ObsidianLink /\[\[.*\]\]/ conceal
      autocmd FileType markdown setlocal conceallevel=2
    augroup END
  ]])

-- Heading colors
vim.cmd [[
  highlight MarkdownH1 guifg=#A7C7E7
  highlight MarkdownH2 guifg=#A3D9B1
  highlight MarkdownH3 guifg=#D1B1D0
  highlight MarkdownH4 guifg=#B3BCE6
  highlight MarkdownH5 guifg=#C2E7F0
  highlight MarkdownH6 guifg=#D9E8D1
]]

vim.cmd [[
  augroup TaskMarkerHighlight
    autocmd!
    " Trigger on opening markdown files
    autocmd FileType markdown lua Apply_task_marker_highlighting()
  augroup END
]]

-- Function to apply task marker highlighting
function Apply_task_marker_highlighting()
  -- Enable syntax highlighting
  vim.cmd('syntax enable')

  -- Match the task markers and assign custom highlights
  vim.cmd('syntax match TaskCreated /@created([^)]*)/')
  vim.cmd('syntax match TaskScheduled /@scheduled([^)]*)/')
  vim.cmd('syntax match TaskDone /@done([^)]*)/')
  vim.cmd('syntax match TaskId /@\\d\\+/')

  -- Define highlight groups for task markers
  vim.cmd('highlight TaskMarkerDone guifg=#6A9955 ctermfg=2')
  vim.cmd('highlight TaskMarkerScheduled     guifg=#D7BA7D ctermfg=3')
  vim.cmd('highlight TaskMarkerCreated    guifg=#CE9178 ctermfg=1')
  vim.cmd('highlight TaskMarkerID guifg=#808080 ctermfg=8')

  -- Link syntax groups to highlight groups
  vim.cmd('highlight link TaskCreated TaskMarkerCreated')
  vim.cmd('highlight link TaskScheduled TaskMarkerScheduled')
  vim.cmd('highlight link TaskDone TaskMarkerDone')
  vim.cmd('highlight link TaskId TaskMarkerID')
end
