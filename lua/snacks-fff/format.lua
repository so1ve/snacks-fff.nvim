local M = {}

local MATCH_PRIORITY = 5000

local function try_require(module)
  local ok, value = pcall(require, module)
  if ok then
    return value
  end
end

local ts_lang_cache = {}

local function basename(path)
  return vim.fn.fnamemodify(path or "", ":t")
end

local function dirname(path)
  local dir = vim.fn.fnamemodify(path or "", ":h")
  return dir ~= "." and dir or ""
end

local function git_sign(status)
  local git_utils = try_require("fff.git_utils")
  local sign = git_utils and git_utils.get_border_char(status) or ""
  local hl = git_utils and git_utils.get_border_highlight(status) or "Comment"

  if sign == "" then
    sign = ({
      untracked = "┆",
      ignored = "┆",
      unknown = "┆",
      modified = "┃",
      deleted = "▁",
      renamed = "┃",
      staged_new = "┃",
      staged_modified = "┃",
      staged_deleted = "▁",
    })[status] or ""
  end

  if sign == "" then
    sign = " "
  end

  if hl == "" then
    hl = "Comment"
  end

  return sign, hl
end

local function file_icon(name, extension)
  local icons = try_require("fff.file_picker.icons")
  if icons then
    local icon, hl = icons.get_icon(name, extension or vim.fn.fnamemodify(name, ":e"), false)
    if icon and icon ~= "" then
      return icon, hl or "Normal"
    end
  end

  return "󰈔", "SnacksPickerFile"
end

local function score_indicator(item)
  local total = item.fff_total_frecency_score or item.total_frecency_score or 0
  local access = item.fff_access_frecency_score or item.access_frecency_score or 0
  local modified = item.fff_modification_frecency_score or item.modification_frecency_score or 0

  if total <= 0 then
    return nil
  end

  local icon = "•"
  if modified >= 6 then
    icon = "🔥"
  elseif access >= 4 then
    icon = "⭐"
  elseif total >= 3 then
    icon = "✨"
  end

  return (" %s%d"):format(icon, total)
end

local function highlight_offset(chunks)
  local highlight = try_require("snacks.picker.util.highlight")
  if highlight and highlight.offset then
    return highlight.offset(chunks)
  end

  local offset = 0

  for _, chunk in ipairs(chunks) do
    if type(chunk[1]) == "string" then
      offset = offset + (chunk.virtual and vim.api.nvim_strwidth(chunk[1]) or #chunk[1])
    end
  end

  return offset
end

local function item_filename(item)
  return item.fff_relative_path
    or item.relative_path
    or item.file
    or item.fff_name
    or item.name
    or basename(item.text or "")
end

local function file_parts(item)
  local relative = item.fff_relative_path or item.relative_path or item.text or item.file or ""
  local name = item.fff_name or item.name or basename(relative)
  local dir = item.fff_dir or item.dir_path or dirname(relative)
  local extension = item.fff_extension or item.extension or vim.fn.fnamemodify(name, ":e")
  return relative, name, dir, extension
end

function M.file(item, picker)
  local _, name, dir, extension = file_parts(item)
  local sign, sign_hl = git_sign(item.fff_git_status or item.git_status)
  local icon, icon_hl = file_icon(name, extension)
  local opts = picker and picker.opts and picker.opts.snacks_fff or {}

  local ret = {
    { sign .. " ", sign_hl, virtual = true },
    { icon .. " ", icon_hl, virtual = true },
    { name, item.fff_filename_hl or "SnacksPickerFile", field = "file" },
  }

  if dir ~= "" then
    ret[#ret + 1] = { " ", virtual = true }
    ret[#ret + 1] = { dir, "Comment", field = "file" }
  end

  if opts.debug_scores then
    local indicator = score_indicator(item)
    if indicator then
      ret[#ret + 1] = { indicator, "Number", virtual = true }
    end
  end

  return ret
end

local function add_match_extmarks(ret, item, offset, hl_group)
  local ranges = item.fff_match_ranges or item.match_ranges
  if type(ranges) ~= "table" or #ranges == 0 then
    return
  end

  for _, range in ipairs(ranges) do
    local start_col = tonumber(range[1]) or 0
    local end_col = tonumber(range[2]) or start_col
    if end_col > start_col then
      ret[#ret + 1] = {
        col = offset + start_col,
        end_col = offset + end_col,
        hl_group = hl_group,
        priority = MATCH_PRIORITY,
      }
    end
  end
end

local function add_syntax_extmarks(ret, item, content, offset)
  local treesitter = try_require("fff.treesitter_hl")
  if not treesitter then
    return
  end

  local filename = item_filename(item)
  local lang = ts_lang_cache[filename]

  if lang == nil then
    lang = treesitter.lang_from_filename(filename) or false
    ts_lang_cache[filename] = lang
  end

  if not lang then
    return
  end

  for _, highlight in ipairs(treesitter.get_line_highlights(content, lang)) do
    ret[#ret + 1] = {
      col = offset + highlight.col,
      end_col = offset + highlight.end_col,
      hl_group = highlight.hl_group,
      priority = 120,
    }
  end
end

local function location_text(line_number, col, opts)
  local location = (":%d:%d"):format(line_number, col + 1)
  local width = tonumber(opts.location_width) or vim.api.nvim_strwidth(location)

  if width > vim.api.nvim_strwidth(location) then
    return location .. string.rep(" ", width - vim.api.nvim_strwidth(location))
  end

  return location
end

function M.grep(item, picker)
  if item.fff_kind == "header" then
    return M.file(item, picker)
  end

  if item.fff_kind == "message" then
    return item.text ~= "" and { { item.text, item.fff_message_hl or "WarningMsg" } } or {}
  end

  if item.fff_kind == "file_suggestion" then
    return M.file(item, picker)
  end

  local line_number = item.fff_line_number or item.line_number or (item.pos and item.pos[1]) or 0
  local col = item.fff_col or item.col or (item.pos and item.pos[2]) or 0
  local content = item.fff_line_content or item.line or item.line_content or ""
  local opts = picker and picker.opts and picker.opts.snacks_fff or {}
  local location = location_text(line_number, col, opts)
  local ret = {}

  ret[#ret + 1] = { " ", virtual = true }
  ret[#ret + 1] = { location, "LineNr", virtual = true }
  ret[#ret + 1] = { "  ", "Comment", virtual = true }

  local content_start = #ret + 1
  local content_offset = highlight_offset(ret)
  ret[#ret + 1] = { content, nil }
  add_syntax_extmarks(ret, item, content, content_offset)
  add_match_extmarks(ret, item, content_offset, opts.match_hl or "SnacksPickerSearch")

  if item.positions then
    local highlight = try_require("snacks.picker.util.highlight")
    if highlight then
      highlight.matches(ret, item.positions, highlight.offset(vim.list_slice(ret, 1, content_start - 1)))
    end
  end

  return ret
end

return M
