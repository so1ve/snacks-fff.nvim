local M = {}

local function notify(message, level)
  vim.notify("snacks-fff: " .. message, level or vim.log.levels.ERROR)
end

local function strip_long_path_prefix(path)
  if type(path) ~= "string" then
    return path
  end

  return vim.startswith(path, "\\\\?\\") and path:sub(5) or path
end

local function normalize_dir(path)
  local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  expanded = strip_long_path_prefix(expanded)
  expanded = vim.fs.normalize(expanded)
  return expanded:gsub("[/\\]+$", "")
end

local function is_absolute(path)
  return path:match("^%a:[/\\]") ~= nil or vim.startswith(path, "/") or vim.startswith(path, "\\\\")
end

local function current_file_cache(base_path)
  if not base_path or base_path == "" then
    return nil
  end

  local current_buf = vim.api.nvim_get_current_buf()
  if not current_buf or not vim.api.nvim_buf_is_valid(current_buf) then
    return nil
  end

  local current_file = vim.api.nvim_buf_get_name(current_buf)
  if current_file == "" then
    return nil
  end

  local stat = vim.uv.fs_stat(current_file)
  if not stat or stat.type ~= "file" then
    return nil
  end

  local resolved_file = vim.fs.normalize(vim.fn.resolve(vim.fn.fnamemodify(current_file, ":p")))
  local resolved_base = normalize_dir(vim.fn.resolve(base_path))
  local escaped_base = resolved_base:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  local relative = resolved_file:gsub("^" .. escaped_base .. "[/\\]", "")

  if relative == "" or relative == resolved_file then
    return nil
  end

  return relative
end

function M.absolute_path(path, base_path)
  path = strip_long_path_prefix(path)
  if not path or path == "" then
    return nil
  end

  if is_absolute(path) then
    return vim.fs.normalize(path)
  end

  local base = base_path or require("fff.conf").get().base_path or vim.fn.getcwd(0)
  return vim.fs.normalize(base .. "/" .. path)
end

function M.change_indexing_directory(path)
  if not path or path == "" then
    notify("directory path is required")
    return false
  end

  local expanded = normalize_dir(path)
  if vim.fn.isdirectory(expanded) ~= 1 then
    notify("directory does not exist: " .. expanded)
    return false
  end

  local conf = require("fff.conf")
  local config = conf.get()
  if config.base_path and normalize_dir(config.base_path) == expanded then
    return true
  end

  local fuzzy = require("fff.core").ensure_initialized()
  local ok, result = pcall(fuzzy.restart_index_in_path, expanded)
  if not ok then
    notify("failed to change indexing directory: " .. tostring(result))
    return false
  end

  config.base_path = expanded

  local ok_file_picker, file_picker = pcall(require, "fff.file_picker")
  if ok_file_picker and file_picker.state then
    file_picker.state.base_path = expanded
  end

  return true
end

function M.ensure_file_picker(cwd)
  local file_picker = require("fff.file_picker")

  if not file_picker.is_initialized() and not file_picker.setup() then
    notify("failed to initialize fff file picker")
    return nil
  end

  M.change_indexing_directory(cwd and cwd ~= "" and cwd or vim.uv.cwd())

  return file_picker
end

function M.refresh_when_scan_finishes(picker, iteration)
  if not picker or picker.closed then
    return
  end

  local file_picker = require("fff.file_picker")
  local progress = file_picker.get_scan_progress()
  if not progress.is_scanning then
    picker:refresh()
    return
  end

  local delay
  if iteration < 10 then
    delay = 100
  elseif iteration < 20 then
    delay = 300
  else
    delay = 500
  end

  vim.defer_fn(function()
    M.refresh_when_scan_finishes(picker, iteration + 1)
  end, delay)
end

function M.find_files(query, opts)
  opts = opts or {}
  local file_picker = M.ensure_file_picker(opts.cwd)
  if not file_picker then
    return {}, nil
  end

  local config = require("fff.conf").get()
  local page_size = opts.page_size or opts.max_results or config.max_results or 100
  local max_threads = opts.max_threads or config.max_threads or 4
  local current_file = current_file_cache(config.base_path)

  local ok, results =
    pcall(file_picker.search_files_paginated, query or "", current_file, max_threads, nil, 0, page_size)

  if not ok then
    notify("file search failed: " .. tostring(results))
    return {}, config.base_path
  end

  return results or {}, config.base_path
end

function M.grep(query, opts, mode)
  opts = opts or {}
  query = query or ""
  if query == "" then
    return {}, require("fff.conf").get().base_path
  end

  if not M.ensure_file_picker(opts.cwd) then
    return {}, nil
  end

  local config = require("fff.conf").get()
  local grep_config = vim.tbl_deep_extend("force", config.grep or {}, opts.grep or opts.grep_config or {})
  local page_size = opts.page_size or opts.max_results or opts.limit_live or opts.limit or config.max_results or 100
  local grep = require("fff.grep")

  local ok, result = pcall(grep.search, query, 0, page_size, grep_config, mode or "plain")
  if not ok then
    notify("grep failed: " .. tostring(result))
    return {}, config.base_path
  end

  return (result and result.items) or {}, config.base_path, result
end

function M.track_access(path)
  local file_picker = M.ensure_file_picker()
  if not file_picker or not path then
    return
  end

  pcall(file_picker.track_access, path)
end

return M
