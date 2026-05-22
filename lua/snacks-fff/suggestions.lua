local items = require("snacks-fff.items")
local modes = require("snacks-fff.modes")

local M = {}

local function suggestion_hl()
  local ok, config = pcall(function()
    return require("fff.conf").get()
  end)

  return ok and config.hl and config.hl.suggestion_header or "WarningMsg"
end

function M.headers()
  return {
    { fff_kind = "message", text = "" },
    {
      fff_kind = "message",
      text = "  No results, try " .. modes.keybind() .. " to fuzzy search",
      fff_message_hl = suggestion_hl(),
    },
    { fff_kind = "message", text = "" },
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
