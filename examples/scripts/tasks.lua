local utils = require("nkm.utils")

return function(_, options)
  -- Get all Markdown files in the quests folder
  local all_tasks = {}
  local files = utils.get_files_in_directory(options.path)
  local today = tostring(os.date("%Y-%m-%d"))
  local current_file = utils.get_current_file()

  -- Iterate over each file and collect in-progress tasks
  for _, file in ipairs(files) do
    if file == current_file and options.ignore_current_file then
      goto continue
    end
    if options.today then
      if not string.find(file, today, 1, true) then
        goto continue
      end
    end
    local tasks = utils.search_tasks_in_file(file, options.status, options.tags, options.label)
    for _, task in ipairs(tasks) do
      table.insert(all_tasks, task)
    end
    ::continue::
  end

  if #all_tasks == 0 then
    return { "~~~~" }
  end
  return all_tasks
end
