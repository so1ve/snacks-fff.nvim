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

local function base_item(item, base_path, kind)
  local relative = relative_path(item)
  local mapped = {
    text = relative,
    file = backend.absolute_path(item.path or relative, base_path),
    preview_title = relative,
    fff_relative_path = relative,
    fff_name = item.name or basename(relative),
    fff_dir = dirname(relative),
    fff_extension = item.extension,
    fff_git_status = item.git_status,
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

function M.file(item, base_path)
  return add_scores(base_item(item, base_path), item)
end

function M.header(item, base_path)
  return base_item(item, base_path, "header")
end

function M.file_suggestion(item, base_path)
  return add_scores(base_item(item, base_path, "file_suggestion"), item)
end

function M.match(item, base_path)
  local relative = relative_path(item)
  local line_number = item.line_number or 0
  local col = item.col or 0
  local content = item.line_content or ""
  local mapped = base_item(item, base_path, "match")

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

  for _, item in ipairs(results or {}) do
    if not item.is_dir then
      mapped[#mapped + 1] = M.file(item, base_path)
    end
  end

  return mapped
end

function M.grep_matches(results, base_path)
  local mapped = {}
  local last_relative_path

  for _, item in ipairs(results or {}) do
    local relative = relative_path(item)
    local match = M.match(item, base_path)

    if relative ~= last_relative_path then
      match.fff_header = M.header(item, base_path)
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
