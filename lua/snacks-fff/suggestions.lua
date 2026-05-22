local items = require("snacks-fff.items")
local modes = require("snacks-fff.modes")

local M = {}

local function message(text, hl)
  return {
    fff_kind = "message",
    text = text,
    fff_message_hl = hl,
  }
end

local function suggestion_hl()
  local ok, config = pcall(function()
    return require("fff.conf").get()
  end)

  return ok and config.hl and config.hl.suggestion_header or "WarningMsg"
end

function M.headers()
  return {
    message(""),
    message("  No results, try " .. modes.keybind() .. " to fuzzy search", suggestion_hl()),
    message(""),
  }
end

function M.grep_empty_items()
  return {
    message("  Start typing to search file contents...", "Comment"),
    message('  "pattern *.rs"    search only in Rust files', "Comment"),
    message('  "pattern /src/"   limit search to src/ directory', "Comment"),
    message('  "!test pattern"   exclude test files', "Comment"),
  }
end

function M.file_items(results, base_path)
  local mapped = {}

  for _, item in ipairs(results or {}) do
    if not item.is_dir then
      local suggestion = items.file_suggestion(item, base_path)
      if #mapped == 0 then
        suggestion.fff_headers = M.headers()
      end
      mapped[#mapped + 1] = suggestion
    end
  end

  return mapped
end

return M
