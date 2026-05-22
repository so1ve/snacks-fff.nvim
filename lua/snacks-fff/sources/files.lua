local backend = require("snacks-fff.backend")
local constants = require("snacks-fff.constants")
local format = require("snacks-fff.format")
local items = require("snacks-fff.items")

local M = {}

function M.finder(opts, ctx)
  local results, base_path = backend.find_files(ctx.filter.search, opts)
  return items.file_list(results, base_path)
end

function M.confirm(picker, item, action)
  if item and item.file then
    backend.track_access(item.file)
  end

  require("snacks.picker.actions").jump(picker, item, action)
end

M.source = {
  source = constants.sources.files,
  title = "FFFiles",
  prompt = "🪿 ",
  live = true,
  show_empty = true,
  finder = M.finder,
  format = format.file,
  preview = "file",
  matcher = { sort = false },
  sort = { fields = { "idx" } },
  confirm = M.confirm,
  on_show = function(picker)
    backend.refresh_when_scan_finishes(picker, 0)
  end,
  snacks_fff = {
    debug_scores = false,
  },
}

return M
