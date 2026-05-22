local M = {}
local constants = require("snacks-fff.constants")

local state = {
  opts = {},
}

local function list(value)
  if value == nil then
    return nil
  end

  if type(value) == "table" then
    return vim.deepcopy(value)
  end

  return { value }
end

local function normalize_grep_opts(opts)
  if opts.grep_modes == nil and opts.grep_mode ~= nil then
    opts.grep_modes = list(opts.grep_mode)
  end

  if opts.grep_modes ~= nil then
    opts.grep_mode = opts.grep_modes
  end

  return opts
end

local function source_for(kind)
  if kind == "find_files" then
    return require("snacks-fff.sources.files").source
  end

  if kind == "live_grep" or kind == "grep_word" then
    return require("snacks-fff.sources.grep").source
  end

  error("unknown snacks-fff picker: " .. tostring(kind))
end

function M.setup(opts)
  vim.validate({ opts = { opts, "table", true } })
  state.opts = vim.deepcopy(opts or {})
end

function M.get()
  return vim.deepcopy(state.opts)
end

function M.make_opts(kind, runtime_opts)
  vim.validate({
    kind = { kind, "string" },
    runtime_opts = { runtime_opts, "table", true },
  })

  local configured = state.opts[kind]
  if kind == "grep_word" and configured == nil then
    configured = state.opts.live_grep
  end

  local opts = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(source_for(kind)),
    vim.deepcopy(configured or {}),
    vim.deepcopy(runtime_opts or {})
  )

  if kind == "grep_word" then
    opts.search = opts.search or function(picker)
      return picker:word()
    end
  end

  if opts.query ~= nil and opts.search == nil then
    opts.search = opts.query
  end

  if kind == "live_grep" or kind == "grep_word" then
    normalize_grep_opts(opts)
    require("snacks-fff.modes").prepare(opts)
  end

  return opts
end

M.constants = constants

return M
