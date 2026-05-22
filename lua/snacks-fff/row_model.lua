local M = {}

function M.item_headers(item)
  if not item then
    return {}
  end

  if item.fff_headers then
    return item.fff_headers
  end

  return item.fff_header and { item.fff_header } or {}
end

function M.item_height(item)
  return 1 + #M.item_headers(item)
end

function M.clamp(value, min, max)
  return math.max(min, math.min(value, max))
end

function M.forward_row(list, visual_row)
  if list.reverse then
    return list.state.height - visual_row + 1
  end

  return visual_row
end

function M.visual_row(list, forward)
  if list.reverse then
    return list.state.height - forward + 1
  end

  return forward
end

function M.rows_before(list, idx)
  local row = 1

  for i = list.top, math.min(idx - 1, list:count()) do
    row = row + M.item_height(list:get(i))
  end

  return row
end

function M.match_forward_row(list, idx)
  return M.rows_before(list, idx) + M.item_height(list:get(idx)) - 1
end

function M.visible_item_count(list, top)
  local count = list:count()
  if count == 0 then
    return 0
  end

  local rows = 0
  local visible = 0
  for idx = top, count do
    local height = M.item_height(list:get(idx))
    if visible > 0 and rows + height > list.state.height then
      break
    end

    rows = rows + height
    visible = visible + 1

    if rows >= list.state.height then
      break
    end
  end

  return math.max(1, visible)
end

function M.row_to_idx(list, row)
  local target = M.forward_row(list, row)
  local current = 1

  for idx = list.top, list:count() do
    local height = M.item_height(list:get(idx))
    if target <= current + height - 1 then
      return idx
    end
    current = current + height
  end

  return list:count()
end

return M
