local config = require("snacks-fff.config")

local M = {}

M.sources = {
  find_files = require("snacks-fff.sources.files").source,
  live_grep = require("snacks-fff.sources.grep").source,
}

function M.setup(opts)
  config.setup(opts)
end

local function pick(kind, opts)
  local snacks = _G.Snacks or require("snacks")
  return snacks.picker.pick(config.make_opts(kind, opts))
end

function M.find_files(opts)
  return pick("find_files", opts)
end

function M.live_grep(opts)
  return pick("live_grep", opts)
end

function M.grep_word(opts)
  return pick("grep_word", opts)
end

function M.find_files_in_dir(directory, opts)
  vim.validate({
    directory = { directory, "string" },
    opts = { opts, "table", true },
  })

  if directory == "" then
    vim.notify("snacks-fff: directory path is required", vim.log.levels.ERROR)
    return
  end

  local merged = vim.tbl_deep_extend("force", {
    cwd = directory,
    title = "Files in " .. vim.fn.fnamemodify(directory, ":t"),
  }, opts or {})

  return M.find_files(merged)
end

return M
