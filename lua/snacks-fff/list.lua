local M = {}

local constants = require("snacks-fff.constants")
local installed = false
local row_model = require("snacks-fff.row_model")

local function is_grep_list(list)
  return list and list.picker and list.picker.opts and list.picker.opts.source == constants.sources.grep
end

local function render_line(list, item, row, ns)
  if row < 1 or row > list.state.height then
    return
  end

  local text, extmarks = list:format(item)
  text = text:gsub("\n", " ")
  vim.api.nvim_buf_set_lines(list.win.buf, row - 1, row, false, { text })

  for _, extmark in ipairs(extmarks) do
    local col = extmark.col
    extmark.col = nil
    extmark.row = nil
    extmark.field = nil
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, list.win.buf, ns, row - 1, col, extmark)
    if not ok and list.picker.opts.debug.extmarks then
      Snacks.notify.error("Failed to set extmark.\n" .. err .. "\n```lua\n" .. vim.inspect(extmark) .. "\n```")
    end
  end
end

function M.install()
  if installed then
    return
  end
  installed = true

  if not _G.Snacks then
    require("snacks")
  end

  local List = require("snacks.picker.core.list")
  local ns = vim.api.nvim_create_namespace("snacks.picker.list")
  local original = {
    idx2row = List.idx2row,
    row2idx = List.row2idx,
    height = List.height,
    _move = List._move,
    _scroll = List._scroll,
    render = List.render,
  }

  function List:idx2row(idx)
    if not is_grep_list(self) then
      return original.idx2row(self, idx)
    end

    return row_model.visual_row(self, row_model.match_forward_row(self, idx))
  end

  function List:row2idx(row)
    if not is_grep_list(self) then
      return original.row2idx(self, row)
    end

    return row_model.row_to_idx(self, row)
  end

  function List:height()
    if not is_grep_list(self) then
      return original.height(self)
    end

    return math.min(row_model.visible_item_count(self, self.top), self:count())
  end

  function List:_move(to, absolute, render)
    if not is_grep_list(self) then
      return original._move(self, to, absolute, render)
    end

    local old_top = self.top
    local count = self:count()
    if count == 0 then
      self.cursor, self.top = 1, 1
    else
      self.cursor = absolute and to or self.cursor + to
      if self.picker.resolved_layout.cycle then
        self.cursor = (self.cursor - 1) % count + 1
      end
      self.cursor = row_model.clamp(self.cursor, 1, count)

      if self.top > self.cursor then
        self.top = self.cursor
      end
      while self.top < self.cursor and row_model.match_forward_row(self, self.cursor) > self.state.height do
        self.top = self.top + 1
      end
    end

    self.dirty = self.dirty or self.top ~= old_top
    if render ~= false then
      self:render()
    end
  end

  function List:_scroll(to, absolute, render)
    if not is_grep_list(self) then
      return original._scroll(self, to, absolute, render)
    end

    local old_top = self.top
    local count = self:count()
    if count == 0 then
      self.top, self.cursor = 1, 1
    else
      self.top = absolute and to or self.top + to
      self.top = row_model.clamp(self.top, 1, count)
      local last = self.top + row_model.visible_item_count(self, self.top) - 1
      self.cursor = row_model.clamp(self.cursor, self.top, math.min(last, count))
    end

    self.dirty = self.dirty or self.top ~= old_top
    if render ~= false then
      self:render()
    end
  end

  function List:render()
    if not is_grep_list(self) then
      return original.render(self)
    end

    if not self.win:valid() then
      return
    end

    if self.target then
      self:view(self.target.cursor, self.target.top, false)
      if not self.picker:is_active() then
        self.target = nil
      end
    else
      self:_move(0, false, false)
      self:scroll(0, false, false)
    end

    local redraw = false
    if self.dirty then
      local height = self.state.height
      self.dirty = false
      vim.api.nvim_win_call(self.win.win, function()
        vim.fn.winrestview({ topline = 1, leftcol = 0 })
      end)

      vim.api.nvim_buf_clear_namespace(self.win.buf, ns, 0, -1)
      vim.bo[self.win.buf].modifiable = true
      local lines = vim.split(string.rep("\n", height), "\n")
      vim.api.nvim_buf_set_lines(self.win.buf, 0, -1, false, lines)

      local pattern = vim.trim(self.picker.input.filter.pattern)
      if self.matcher.pattern ~= pattern then
        self.matcher:init(pattern)
      end
      local search = Snacks.picker.util.parse(vim.trim(self.picker.input.filter.search))
      if self.matcher_regex.pattern ~= search then
        self.matcher_regex:init(search)
      end

      self.visible = {}
      for idx = self.top, self:count() do
        local item = assert(self:get(idx), "item not found")
        local start = row_model.rows_before(self, idx)
        if start > height then
          break
        end

        self.visible[#self.visible + 1] = item
        for offset, header in ipairs(row_model.item_headers(item)) do
          render_line(self, header, row_model.visual_row(self, start + offset - 1), ns)
        end

        local row = self:idx2row(idx)
        render_line(self, item, row, ns)
      end

      vim.bo[self.win.buf].modifiable = false
      redraw = true
    end

    self:update_cursorline()
    local row = self:idx2row(self.cursor)
    if row >= 1 and row <= self.state.height then
      local cursor = vim.api.nvim_win_get_cursor(self.win.win)
      if cursor[1] ~= row then
        vim.api.nvim_win_set_cursor(self.win.win, { row, 0 })
      end
    end

    if redraw then
      self.win:redraw()
    end

    if self.target then
      return
    end

    local current = self:current()
    if self._current ~= current then
      self._current = current
      if not self.did_preview then
        self.did_preview = true
        self.picker:show_preview()
      else
        vim.schedule(function()
          if self.picker then
            self.picker:show_preview()
          end
        end)
      end
    end
  end
end

return M
