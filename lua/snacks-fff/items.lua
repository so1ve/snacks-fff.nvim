local backend = require("snacks-fff.backend")

local M = {}

local function relative_path(item)
  return item.relative_path or item.path or item.name or ""
end

local function basename(path)
  return vim.fn.fnamemodify(path or "", ":t")
end

local function dirname(path)
  local dir = vim.fn.fnamemodify(path or "", ":h")
  return dir ~= "." and dir or ""
end

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function current_file_path()
  local current = vim.api.nvim_buf_get_name(0)
  return normalize_path(current)
end

local function context()
  return { current_file = current_file_path() }
end

local function is_current_file(item, absolute, ctx)
  if item.current_file == true or item.is_current_file == true then
    return true
  end

  return ctx and ctx.current_file ~= nil and absolute ~= nil and ctx.current_file == absolute
end

local function base_item(item, base_path, kind, ctx)
  local relative = relative_path(item)
  local absolute = backend.absolute_path(item.path or relative, base_path)
  ctx = ctx or context()

  local mapped = {
    text = relative,
    file = absolute,
    preview_title = relative,
    fff_relative_path = relative,
    fff_name = item.name or basename(relative),
    fff_dir = dirname(relative),
    fff_extension = item.extension,
    fff_git_status = item.git_status,
    fff_is_current_file = kind ~= "match" and is_current_file(item, absolute, ctx),
    fff_raw = item,
  }

  if kind then
    mapped.fff_kind = kind
  end

  return mapped
end

local function add_scores(mapped, item)
  mapped.fff_total_frecency_score = item.total_frecency_score
  mapped.fff_access_frecency_score = item.access_frecency_score
  mapped.fff_modification_frecency_score = item.modification_frecency_score
  return mapped
end

function M.file(item, base_path, ctx)
  return add_scores(base_item(item, base_path, nil, ctx), item)
end

function M.header(item, base_path, ctx)
  return base_item(item, base_path, "header", ctx)
end

function M.file_suggestion(item, base_path, ctx)
  return add_scores(base_item(item, base_path, "file_suggestion", ctx), item)
end

function M.match(item, base_path, ctx)
  local relative = relative_path(item)
  local line_number = item.line_number or 0
  local col = item.col or 0
  local content = item.line_content or ""
  local mapped = base_item(item, base_path, "match", ctx)

  mapped.text = ("%s:%d:%d:%s"):format(relative, line_number, col + 1, content)
  mapped.pos = { line_number, col }
  mapped.fff_line_number = line_number
  mapped.fff_col = col
  mapped.fff_line_content = content
  mapped.fff_match_ranges = item.match_ranges
  mapped.fff_match_positions = item.match_positions

  return mapped
end

function M.file_list(results, base_path)
  local mapped = {}
  local ctx = context()

  for _, item in ipairs(results or {}) do
    if not item.is_dir then
      mapped[#mapped + 1] = M.file(item, base_path, ctx)
    end
  end

  return mapped
end

function M.grep_matches(results, base_path)
  local mapped = {}
  local last_relative_path
  local ctx = context()

  for _, item in ipairs(results or {}) do
    local relative = relative_path(item)
    local match = M.match(item, base_path, ctx)

    if relative ~= last_relative_path then
      match.fff_header = M.header(item, base_path, ctx)
    end

    mapped[#mapped + 1] = match
    last_relative_path = relative
  end

  return mapped
end

function M.location_width(results)
  local width = 0

  for _, item in ipairs(results or {}) do
    local location = (":%d:%d"):format(item.line_number or 0, (item.col or 0) + 1)
    width = math.max(width, vim.api.nvim_strwidth(location))
  end

  return width
end

return M
