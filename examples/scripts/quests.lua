local utils = require("nkm.utils")

return function(file_path, options)
  local dir = (options.path or file_path):match("(.*/)")
  if not dir then return { "<invalid source file path>" } end

  local p = io.popen('ls "' .. dir .. '"')
  if not p then return { "<cannot list directory: " .. dir .. ">" } end

  local characters = {}

  for file in p:lines() do
    if file:match("%.md$") then
      local full_path = dir .. file
      local frontmatter = utils.read_frontmatter(full_path)
      if frontmatter then
        if frontmatter["type"] == "quest" then
          table.insert(characters, {frontmatter["name"], frontmatter["status"]})
        end
      end
    end
  end

  p:close()

  table.insert(characters, 1, {"Name", "Status"})
  characters = utils.format_table(characters, {separator = true})

  return characters
end
