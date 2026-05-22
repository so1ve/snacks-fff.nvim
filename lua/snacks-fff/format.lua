local M = {}

local MATCH_PRIORITY = 5000

local module_cache = {}
local fff_highlights_ready = false

local function try_require(module)
  if module_cache[module] then
    return module_cache[module]
  end

  local ok, value = pcall(require, module)
  if ok then
    module_cache[module] = value
    return value
  end
end

local function fff_config()
  local ok, config = pcall(function()
    return require("fff.conf").get()
  end)

  return ok and config or {}
end

local ts_lang_cache = {}

local function basename(path)
  return vim.fn.fnamemodify(path or "", ":t")
end

local function dirname(path)
  local dir = vim.fn.fnamemodify(path or "", ":h")
  return dir ~= "." and dir or ""
end

local function call(module, name, ...)
  local fn = module and module[name]
  if type(fn) ~= "function" then
    return nil
  end

  local ok, value = pcall(fn, ...)
  if ok then
    return value
  end
end

local function ensure_fff_highlights(highlights)
  if fff_highlights_ready then
    return
  end

  highlights = highlights or try_require("fff.highlights")
  if not highlights or type(highlights.setup) ~= "function" then
    return
  end

  local ok = pcall(highlights.setup)
  if ok then
    fff_highlights_ready = true
  end
end

local function fallback_git_border_char(status)
  return ({
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

local function fallback_git_border_highlight(status, config)
  local hl = config.hl or {}
  return ({
    untracked = hl.git_sign_untracked,
    ignored = hl.git_sign_ignored,
    unknown = hl.git_sign_untracked,
    modified = hl.git_sign_modified,
    deleted = hl.git_sign_deleted,
    renamed = hl.git_sign_renamed,
    staged_new = hl.git_sign_staged,
    staged_modified = hl.git_sign_staged,
    staged_deleted = hl.git_sign_staged,
  })[status] or ""
end

local function git_sign(status, config)
  local highlights = try_require("fff.highlights")
  local git_utils = try_require("fff.git_utils")
  ensure_fff_highlights(highlights)
  local sign = call(highlights, "get_git_border_char", status) or call(git_utils, "get_border_char", status) or ""
  local hl = call(highlights, "get_git_border_highlight", status)
    or call(git_utils, "get_border_highlight", status)
    or ""

  if sign == "" then
    sign = fallback_git_border_char(status)
  end

  if sign == "" then
    sign = " "
  end

  if hl == "" then
    hl = fallback_git_border_highlight(status, config)
  end

  if hl == "" then
    hl = "Comment"
  end

  return sign, hl
end

local function git_text_highlight(status, config)
  if not status then
    return nil
  end

  local highlights = try_require("fff.highlights")
  local git_utils = try_require("fff.git_utils")
  local hl = call(highlights, "get_git_text_highlight", status) or call(git_utils, "get_text_highlight", status)
  if hl and hl ~= "" then
    return hl
  end

  local fff_hl = config.hl or {}
  return ({
    untracked = fff_hl.git_untracked,
    unknown = fff_hl.git_untracked,
    modified = fff_hl.git_modified,
    deleted = fff_hl.git_deleted,
    renamed = fff_hl.git_renamed,
    staged_new = fff_hl.git_staged,
    staged_modified = fff_hl.git_staged,
    staged_deleted = fff_hl.git_staged,
    ignored = fff_hl.git_ignored,
  })[status]
end

local function git_status_text_color_enabled(config)
  return config.git and config.git.status_text_color == true
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

local function current_file_label(config)
  return config.file_picker and config.file_picker.current_file_label or "(current)"
end

function M.file(item, picker)
  local _, name, dir, extension = file_parts(item)
  local git_status = item.fff_git_status or item.git_status
  local config = fff_config()
  local sign, sign_hl = git_sign(git_status, config)
  local icon, icon_hl = file_icon(name, extension)
  local is_current_file = item.fff_is_current_file == true or item.is_current_file == true
  local filename_hl = item.fff_filename_hl or "SnacksPickerFile"

  if is_current_file then
    icon_hl = "Comment"
  elseif git_status_text_color_enabled(config) then
    filename_hl = git_text_highlight(git_status, config) or filename_hl
  end

  local ret = {
    { sign .. " ", sign_hl, virtual = true },
    { icon .. " ", icon_hl, virtual = true },
    { name, filename_hl, field = "file" },
  }

  if dir ~= "" then
    ret[#ret + 1] = { " ", virtual = true }
    ret[#ret + 1] = { dir, "Comment", field = "file" }
  end

  if config.debug and config.debug.show_scores then
    local indicator = score_indicator(item)
    if indicator then
      ret[#ret + 1] = { indicator, "Number", virtual = true }
    end
  end

  local label = current_file_label(config)
  if is_current_file and label and label ~= "" then
    ret[#ret + 1] = {
      col = 0,
      virt_text = { { " " .. label, "Comment" } },
      virt_text_pos = "right_align",
    }
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
