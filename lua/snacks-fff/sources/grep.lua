local backend = require("snacks-fff.backend")
local constants = require("snacks-fff.constants")
local format = require("snacks-fff.format")
local input = require("snacks-fff.input")
local items = require("snacks-fff.items")
local list = require("snacks-fff.list")
local modes = require("snacks-fff.modes")
local suggestions = require("snacks-fff.suggestions")

local M = {}

list.install()
input.install()

local function count1()
  return vim.fn.mode():sub(1, 1) == "i" and 1 or vim.v.count1
end

function M.finder(opts, ctx)
  local query = ctx.filter.search or ""
  local results, base_path = backend.grep(query, opts, modes.current(opts))

  opts.snacks_fff = opts.snacks_fff or {}
  opts.snacks_fff.location_width = items.location_width(results)
  opts.snacks_fff.suggestion_source = nil

  if #results == 0 and query ~= "" then
    local file_results, file_base_path = backend.find_files(query, opts)
    base_path = file_base_path or base_path
    local fallback_items = suggestions.file_items(file_results, base_path)
    if #fallback_items > 0 then
      opts.snacks_fff.suggestion_source = "files"
      return fallback_items
    end
  end

  return items.grep_matches(results, base_path)
end

function M.confirm(picker, item, action)
  require("snacks.picker.actions").jump(picker, item, action)
end

function M.list_top(picker)
  picker.list:move(1, true)
end

function M.list_bottom(picker)
  picker.list:move(picker.list:count(), true)
end

function M.list_down(picker)
  picker.list:move(count1())
end

function M.list_up(picker)
  picker.list:move(-count1())
end

function M.select_and_next(picker)
  picker.list:select()
  picker.list:move(count1())
end

function M.select_and_prev(picker)
  picker.list:select()
  picker.list:move(-count1())
end

function M.select_all(picker)
  picker.list:set_selected(#picker.list.selected == picker.list:count() and {} or picker.list.items)
end

function M.on_show(picker)
  backend.refresh_when_scan_finishes(picker, 0)
end

function M.cycle_grep_mode(picker)
  modes.cycle(picker)
end

local function configure(opts)
  list.install()
  input.install()
  return opts
end

M.source = {
  source = constants.sources.grep,
  title = "Live Grep",
  prompt = "🪿 ",
  live = true,
  show_empty = true,
  finder = M.finder,
  format = format.grep,
  preview = "file",
  matcher = { sort = false },
  sort = { fields = { "idx" } },
  grep_modes = modes.DEFAULT,
  config = configure,
  confirm = M.confirm,
  on_show = M.on_show,
  actions = {
    cycle_grep_mode = M.cycle_grep_mode,
    list_top = M.list_top,
    list_bottom = M.list_bottom,
    list_down = M.list_down,
    list_up = M.list_up,
    select_all = M.select_all,
    select_and_next = M.select_and_next,
    select_and_prev = M.select_and_prev,
  },
}

return M
