local M = {}

local constants = require("snacks-fff.constants")
local installed = false
local ns = vim.api.nvim_create_namespace("snacks-fff.input")
local snacks_input_ns = vim.api.nvim_create_namespace("snacks.picker.input")
local modes = require("snacks-fff.modes")

local function is_grep_input(input)
  return input and input.picker and input.picker.opts and input.picker.opts.source == constants.sources.grep
end

local function right_padding(input)
  local opts = input.picker.opts.snacks_fff or {}
  return math.max(0, tonumber(opts.grep_mode_hint_right_padding or opts.grep_mode_hint_padding) or 4)
end

local function win_width(input)
  local win = input.win and input.win.win
  if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_width(win)
  end

  return vim.o.columns
end

function M.render(input)
  if not is_grep_input(input) or not input.win:valid() then
    return
  end

  vim.api.nvim_buf_clear_namespace(input.win.buf, ns, 0, -1)

  local current_hint = modes.hint(input.picker.opts)
  if not current_hint then
    return
  end

  pcall(vim.api.nvim_buf_del_extmark, input.win.buf, snacks_input_ns, 999)

  local col = math.max(0, win_width(input) - vim.api.nvim_strwidth(current_hint.text) - right_padding(input))

  vim.api.nvim_buf_set_extmark(input.win.buf, ns, 0, 0, {
    virt_text = current_hint.chunks,
    virt_text_win_col = col,
    hl_mode = "combine",
  })
end

function M.install()
  if installed then
    return
  end
  installed = true

  if not _G.Snacks then
    require("snacks")
  end

  local Input = require("snacks.picker.core.input")
  local original_update = Input.update
  local original_set = Input.set

  function Input:update(...)
    local ret = original_update(self, ...)
    M.render(self)
    return ret
  end

  function Input:set(...)
    local ret = original_set(self, ...)
    M.render(self)
    return ret
  end
end

return M
