local M = {}

M.DEFAULT = { "plain", "regex", "fuzzy" }

local function fff_config()
  local ok, config = pcall(function()
    return require("fff.conf").get()
  end)

  return ok and config or {}
end

local function as_list(value)
  if type(value) == "string" then
    return { value }
  end

  if type(value) == "table" then
    return vim.deepcopy(value)
  end

  return vim.deepcopy(M.DEFAULT)
end

function M.available(opts)
  opts = opts or {}
  return as_list(opts.grep_modes or opts.grep_mode or (opts.grep and opts.grep.modes))
end

function M.current(opts)
  opts = opts or {}
  local state = opts.snacks_fff or {}
  return state.grep_mode or M.available(opts)[1] or "plain"
end

function M.keybind()
  local config = fff_config()
  local value = config.keymaps and config.keymaps.cycle_grep_modes or "<S-Tab>"

  if type(value) == "table" then
    return value[1] or "<S-Tab>"
  end

  return value
end

function M.highlight(mode)
  local hl = fff_config().hl or {}

  if mode == "regex" then
    return hl.grep_regex_active or "DiagnosticInfo"
  end

  if mode == "fuzzy" then
    return hl.grep_fuzzy_active or "DiagnosticHint"
  end

  return hl.grep_plain_active or "Comment"
end

function M.hint(opts)
  opts = opts or {}
  local state = opts.snacks_fff or {}

  if state.show_grep_mode_hint == false or #M.available(opts) <= 1 then
    return nil
  end

  local key = M.keybind()
  local mode = M.current(opts)
  local hl = M.highlight(mode)

  return {
    text = ("%s %s"):format(key, mode),
    chunks = {
      { key .. " ", hl },
      { mode, hl },
    },
  }
end

local function add_cycle_key(keys, mode)
  local key = M.keybind()
  keys[key] = keys[key] or { "cycle_grep_mode", mode = mode, desc = "Cycle grep mode" }
end

function M.apply_keymaps(opts)
  opts.win = opts.win or {}
  opts.win.input = opts.win.input or {}
  opts.win.input.keys = opts.win.input.keys or {}
  opts.win.list = opts.win.list or {}
  opts.win.list.keys = opts.win.list.keys or {}

  add_cycle_key(opts.win.input.keys, { "i", "n" })
  add_cycle_key(opts.win.list.keys, { "n", "x" })

  return opts
end

function M.prepare(opts)
  local available = M.available(opts)

  opts.snacks_fff = vim.tbl_deep_extend("force", {
    grep_mode = available[1] or "plain",
    grep_mode_hint_right_padding = 4,
    match_hl = "SnacksPickerSearch",
    show_grep_mode_hint = true,
  }, opts.snacks_fff or {})

  opts.title = opts.title or "Live Grep"
  return M.apply_keymaps(opts)
end

function M.cycle(picker)
  local available = M.available(picker.opts)
  if #available <= 1 then
    return
  end

  local state = picker.opts.snacks_fff or {}
  local mode = state.grep_mode or available[1]
  local index = 1

  for i, value in ipairs(available) do
    if value == mode then
      index = i
      break
    end
  end

  state.grep_mode = available[(index % #available) + 1]
  picker.opts.snacks_fff = state
  picker.input:update()
  picker:update_titles()
  picker:refresh()
end

return M
