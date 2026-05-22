local root = vim.fn.getcwd()
local data = vim.fn.stdpath("data")
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/lua/?/?.lua",
  data .. "/lazy/fff.nvim/lua/?.lua",
  data .. "/lazy/fff.nvim/lua/?/init.lua",
  data .. "/lazy/fff.nvim/lua/?/?.lua",
  data .. "/lazy/snacks.nvim/lua/?.lua",
  data .. "/lazy/snacks.nvim/lua/?/init.lua",
  data .. "/lazy/snacks.nvim/lua/?/?.lua",
  package.path,
}, ";")

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(
      (message or "values are not equal")
        .. "\nactual: "
        .. vim.inspect(actual)
        .. "\nexpected: "
        .. vim.inspect(expected),
      2
    )
  end
end

local function assert_truthy(value, message)
  if not value then
    error(message or "expected truthy value", 2)
  end
end

local snacks_fff = require("snacks-fff")
local config = require("snacks-fff.config")
local format = require("snacks-fff.format")
local input = require("snacks-fff.input")
local items = require("snacks-fff.items")
local modes = require("snacks-fff.modes")
local backend = require("snacks-fff.backend")
local grep_source = require("snacks-fff.sources.grep")
input.install()
require("snacks-fff.list").install()

assert_equal(type(snacks_fff.setup), "function", "setup() is public")
assert_equal(type(snacks_fff.find_files), "function", "find_files() is public")
assert_equal(type(snacks_fff.live_grep), "function", "live_grep() is public")
assert_equal(type(snacks_fff.grep_word), "function", "grep_word() is public")
assert_equal(type(snacks_fff.find_files_in_dir), "function", "find_files_in_dir() is public")
assert_equal(type(snacks_fff.sources), "table", "sources table is public")

snacks_fff.setup({
  find_files = {
    title = "Configured files",
    layout = { preset = "vertical" },
  },
  live_grep = {
    grep_modes = { "fuzzy", "plain" },
    layout = { preset = "ivy" },
  },
})

local files_opts = config.make_opts("find_files", {
  title = "Runtime files",
  cwd = "C:/repo",
})

assert_equal(files_opts.title, "Runtime files", "runtime opts override configured find_files title")
assert_equal(files_opts.cwd, "C:/repo", "runtime cwd is preserved")
assert_equal(files_opts.layout.preset, "vertical", "configured nested find_files opts are preserved")
assert_equal(files_opts.source, "snacks_fff_files", "find_files uses a stable source name")
assert_equal(files_opts.live, true, "find_files is a live Snacks picker")

local grep_opts = config.make_opts("live_grep")
assert_equal(grep_opts.grep_modes, { "fuzzy", "plain" }, "live_grep keeps configured grep mode order")
assert_equal(grep_opts.source, "snacks_fff_grep", "live_grep uses a stable source name")
assert_equal(grep_opts.title, "Live Grep", "live_grep title does not duplicate the grep mode")
assert_equal(grep_opts.layout.preset, "ivy", "configured nested live_grep opts are preserved")
assert_equal(grep_opts.snacks_fff.grep_mode_hint_right_padding, 4, "live_grep uses fixed right hint padding")
assert_equal(
  grep_opts.win.input.keys["<S-Tab>"][1],
  "cycle_grep_mode",
  "live_grep binds the default grep mode cycle key before Snacks keymap merging"
)
assert_equal(
  grep_opts.win.list.keys["<S-Tab>"][1],
  "cycle_grep_mode",
  "live_grep binds the default grep mode cycle key before Snacks list keymap merging"
)
grep_opts.config(grep_opts)

local fff_config = require("fff.conf").get()
local original_cycle_key = fff_config.keymaps.cycle_grep_modes
fff_config.keymaps.cycle_grep_modes = "<C-g>"
local custom_key_opts = config.make_opts("live_grep", { grep_modes = { "plain", "regex" } })
assert_equal(
  custom_key_opts.win.input.keys["<C-g>"][1],
  "cycle_grep_mode",
  "custom fff cycle key is used for the pre-merge input window binding"
)
assert_equal(
  custom_key_opts.win.list.keys["<C-g>"][1],
  "cycle_grep_mode",
  "custom fff cycle key is used for the pre-merge list window binding"
)
assert_equal(custom_key_opts.win.input.keys["<S-Tab>"], nil, "custom cycle key does not leave a stale input binding")
assert_equal(custom_key_opts.win.list.keys["<S-Tab>"], nil, "custom cycle key does not leave a stale list binding")
assert_equal(modes.hint(custom_key_opts).text, "<C-g> plain", "custom fff cycle key is used for the input hint")
custom_key_opts.config(custom_key_opts)
fff_config.keymaps.cycle_grep_modes = original_cycle_key

local original_prepare = modes.prepare
local prepare_calls = 0
modes.prepare = function(opts)
  prepare_calls = prepare_calls + 1
  return original_prepare(opts)
end
local single_prepare_opts = config.make_opts("live_grep", { grep_modes = { "plain", "regex" } })
single_prepare_opts.config(single_prepare_opts)
modes.prepare = original_prepare
assert_equal(prepare_calls, 1, "grep mode options are prepared once before Snacks config hook execution")

local grep_word_opts = config.make_opts("grep_word")
assert_equal(grep_word_opts.grep_modes, { "fuzzy", "plain" }, "grep_word falls back to live_grep defaults")
assert_equal(type(grep_word_opts.search), "function", "grep_word supplies a word search function")

local original_show_scores = fff_config.debug.show_scores
local original_status_text_color = fff_config.git.status_text_color
local original_current_file_label = fff_config.file_picker.current_file_label
fff_config.debug.show_scores = true
fff_config.git.status_text_color = true
fff_config.file_picker.current_file_label = "(active)"

local file_chunks = format.file({
  text = "lua/plugins/fff.lua",
  file = "C:/repo/lua/plugins/fff.lua",
  fff_name = "fff.lua",
  fff_dir = "lua/plugins",
  fff_extension = "lua",
  fff_git_status = "modified",
  fff_total_frecency_score = 7,
}, { opts = { snacks_fff = {} } })

assert_truthy(#file_chunks >= 5, "file formatter returns multiple highlighted chunks")
assert_equal(file_chunks[1][1], "┃ ", "file formatter starts with fff git sign")
assert_truthy(
  vim.tbl_contains(
    vim.tbl_map(function(chunk)
      return chunk[1]
    end, file_chunks),
    "fff.lua"
  ),
  "file formatter includes the filename first"
)
assert_truthy(
  vim.tbl_contains(
    vim.tbl_map(function(chunk)
      return chunk[1]
    end, file_chunks),
    " ✨7"
  ),
  "file formatter renders the fff frecency indicator when debug scores are enabled"
)

local git_sign_cases = {
  untracked = "┆ ",
  deleted = "▁ ",
  staged_new = "┃ ",
  clean = "  ",
}
for status, expected_sign in pairs(git_sign_cases) do
  local chunks = format.file({ fff_name = "git.lua", fff_git_status = status }, { opts = { snacks_fff = {} } })
  assert_equal(chunks[1][1], expected_sign, "file formatter renders fff git sign for " .. status)
end

local git_colored_chunks = format.file({
  fff_name = "git.lua",
  fff_git_status = "modified",
}, { opts = { snacks_fff = {} } })
assert_equal(
  git_colored_chunks[3][2],
  "FFFGitModified",
  "file formatter can color filename text with fff git status highlight"
)

local current_file_chunks = format.file({
  fff_name = "current.lua",
  fff_extension = "lua",
  fff_is_current_file = true,
}, { opts = { snacks_fff = {} } })
assert_equal(current_file_chunks[2][2], "Comment", "current file icon is dimmed like original fff")
local current_file_label
for _, chunk in ipairs(current_file_chunks) do
  if chunk.virt_text then
    current_file_label = chunk.virt_text[1][1]
    break
  end
end
assert_equal(current_file_label, " (active)", "current file label renders as right-aligned virtual text")

fff_config.debug.show_scores = false
local no_score_chunks = format.file({
  fff_name = "score.lua",
  fff_total_frecency_score = 9,
}, { opts = { snacks_fff = { debug_scores = true } } })
assert_equal(
  vim.tbl_contains(
    vim.tbl_map(function(chunk)
      return chunk[1]
    end, no_score_chunks),
    " ✨9"
  ),
  false,
  "snacks-fff debug_scores override is ignored because fff debug.show_scores is the source of truth"
)
fff_config.debug.show_scores = true

local temp_file = vim.fn.tempname() .. ".lua"
vim.fn.writefile({ "return true" }, temp_file)
local previous_buf = vim.api.nvim_get_current_buf()
vim.cmd.edit(vim.fn.fnameescape(temp_file))
local temp_dir = vim.fs.dirname(temp_file)
local temp_name = vim.fn.fnamemodify(temp_file, ":t")
local current_item = items.file({ path = temp_name, relative_path = temp_name, name = temp_name }, temp_dir)
vim.api.nvim_set_current_buf(previous_buf)
pcall(vim.fn.delete, temp_file)
assert_equal(current_item.fff_is_current_file, true, "item mapper marks the current buffer file")

local original_absolute_path = backend.absolute_path
local absolute_path_calls = 0
backend.absolute_path = function(path, base_path)
  absolute_path_calls = absolute_path_calls + 1
  return original_absolute_path(path, base_path)
end
items.grep_matches({
  { path = "a.lua", relative_path = "a.lua", name = "a.lua", line_number = 1, col = 0, line_content = "alpha" },
  { path = "a.lua", relative_path = "a.lua", name = "a.lua", line_number = 2, col = 0, line_content = "again" },
  { path = "b.lua", relative_path = "b.lua", name = "b.lua", line_number = 1, col = 0, line_content = "beta" },
}, "C:/repo")
backend.absolute_path = original_absolute_path
assert_equal(
  absolute_path_calls,
  5,
  "grep result mapping computes each item/header absolute path once without extra current-file resolution"
)

fff_config.debug.show_scores = original_show_scores
fff_config.git.status_text_color = original_status_text_color
fff_config.file_picker.current_file_label = original_current_file_label

local grep_header_chunks = format.grep({
  text = "lua/plugins/fff.lua",
  file = "C:/repo/lua/plugins/fff.lua",
  fff_kind = "header",
  fff_name = "fff.lua",
  fff_dir = "lua/plugins",
  fff_git_status = "modified",
}, { opts = { snacks_fff = { grep_mode = "plain", show_grep_mode_hint = true } } })

assert_truthy(
  vim.tbl_contains(
    vim.tbl_map(function(chunk)
      return chunk[1]
    end, grep_header_chunks),
    "fff.lua"
  ),
  "grep header item renders the filename as its own visual row"
)
assert_equal(grep_header_chunks[1][1], "┃ ", "grep header item keeps fff git sign styling")

local grep_chunks = format.grep({
  text = "lua/plugins/fff.lua:12:3:local picker = true",
  file = "C:/repo/lua/plugins/fff.lua",
  fff_kind = "match",
  fff_name = "fff.lua",
  fff_dir = "lua/plugins",
  fff_line_number = 12,
  fff_col = 2,
  fff_line_content = "local picker = true",
  fff_match_ranges = { { 6, 12 } },
}, { opts = { snacks_fff = { grep_mode = "plain", location_width = 8, show_grep_mode_hint = true } } })

assert_truthy(#grep_chunks >= 6, "grep formatter returns highlighted grep chunks")
local grep_text_chunks = vim.tbl_map(function(chunk)
  return chunk[1]
end, grep_chunks)
assert_equal(
  vim.tbl_contains(grep_text_chunks, "fff.lua"),
  false,
  "grep match line does not include selectable file header text"
)
assert_truthy(
  vim.tbl_contains(grep_text_chunks, ":12:3   "),
  "grep formatter left-aligns line and column in a fixed width"
)
assert_equal(
  vim.tbl_contains(grep_text_chunks, "<S-Tab> plain"),
  false,
  "grep formatter does not render the mode hint inside result rows"
)

local content_offset = 0
for _, chunk in ipairs(grep_chunks) do
  if chunk[1] == "local picker = true" then
    break
  end

  if type(chunk[1]) == "string" then
    content_offset = content_offset + (chunk.virtual and vim.api.nvim_strwidth(chunk[1]) or #chunk[1])
  end
end

local match_extmark
for _, chunk in ipairs(grep_chunks) do
  if chunk.hl_group == "SnacksPickerSearch" then
    match_extmark = chunk
    break
  end
end

assert_truthy(match_extmark, "grep formatter creates a match extmark for fff match ranges")
assert_equal(
  match_extmark.hl_group,
  "SnacksPickerSearch",
  "grep match ranges mirror Snacks preview search highlighting"
)
assert_equal(match_extmark.col, content_offset + 6, "grep match range starts inside the displayed content")
assert_equal(match_extmark.end_col, content_offset + 12, "grep match range ends inside the displayed content")
assert_equal(match_extmark.priority, 5000, "grep match ranges stay above Snacks list matcher overlays")

local syntax_extmark
for _, chunk in ipairs(grep_chunks) do
  if chunk.hl_group == "@keyword.lua" then
    syntax_extmark = chunk
    break
  end
end

assert_truthy(syntax_extmark, "grep formatter applies treesitter syntax highlighting to result content")
assert_equal(syntax_extmark.col, content_offset, "syntax highlighting starts at the content column")
assert_equal(syntax_extmark.end_col, content_offset + 5, "syntax highlighting ends inside the content column")

local custom_match_chunks = format.grep({
  text = "lua/plugins/fff.lua:12:3:local picker = true",
  file = "C:/repo/lua/plugins/fff.lua",
  fff_kind = "match",
  fff_line_number = 12,
  fff_col = 2,
  fff_line_content = "local picker = true",
  fff_match_ranges = { { 6, 12 } },
}, { opts = { snacks_fff = { match_hl = "Search" } } })

local custom_match_extmark
for _, chunk in ipairs(custom_match_chunks) do
  if chunk.hl_group == "Search" then
    custom_match_extmark = chunk
    break
  end
end

assert_truthy(custom_match_extmark, "grep match highlight group is configurable")

local file_suggestion_chunks = format.grep({
  text = "lua/plugins/fff.lua",
  file = "C:/repo/lua/plugins/fff.lua",
  fff_kind = "file_suggestion",
  fff_name = "fff.lua",
  fff_dir = "lua/plugins",
}, { opts = { snacks_fff = {} } })

assert_truthy(
  vim.tbl_contains(
    vim.tbl_map(function(chunk)
      return chunk[1]
    end, file_suggestion_chunks),
    "fff.lua"
  ),
  "file suggestions render like file picker rows"
)

local List = require("snacks.picker.core.list")
local fake_list = setmetatable({
  picker = { opts = { source = "snacks_fff_grep" } },
  top = 1,
  cursor = 1,
  reverse = false,
  state = { height = 6 },
  items = {
    { fff_kind = "match", fff_headers = { { fff_kind = "message", text = "" }, { fff_kind = "header" } } },
    { fff_kind = "match" },
    { fff_kind = "match", fff_header = { fff_kind = "header" } },
    { fff_kind = "match" },
  },
  count = function(self)
    return #self.items
  end,
  get = function(self, idx)
    return self.items[idx]
  end,
}, { __index = List })

assert_equal(fake_list:idx2row(1), 3, "first match cursor row is below its visual headers")
assert_equal(fake_list:row2idx(1), 1, "clicking a header row maps to its owning match item")
assert_equal(fake_list:row2idx(3), 1, "clicking a match row maps to the same match item")
assert_equal(fake_list:idx2row(2), 4, "plain match row follows the previous match")
assert_equal(fake_list:idx2row(3), 6, "next file group reserves one non-item header row")
assert_equal(fake_list:row2idx(5), 3, "clicking a later header maps to the next match item")

local fake_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(fake_buf, 0, -1, false, { "snacks" })
local input_width = vim.api.nvim_win_get_width(0)
local snacks_input_ns = vim.api.nvim_create_namespace("snacks.picker.input")
vim.api.nvim_buf_set_extmark(fake_buf, snacks_input_ns, 0, 0, {
  id = 999,
  virt_text = { { "(1) 2/3 ", "SnacksPickerTotals" } },
  virt_text_pos = "right_align",
})
local fake_input = {
  picker = {
    opts = {
      source = "snacks_fff_grep",
      grep_modes = { "plain", "regex", "fuzzy" },
      snacks_fff = { grep_mode = "plain", grep_mode_hint_right_padding = 4 },
    },
  },
  win = {
    buf = fake_buf,
    win = vim.api.nvim_get_current_win(),
    valid = function()
      return true
    end,
  },
}

input.render(fake_input)

assert_equal(
  vim.api.nvim_buf_get_extmark_by_id(fake_buf, snacks_input_ns, 999, {}),
  {},
  "grep mode hint removes Snacks input totals extmark to avoid right-edge overlap"
)

local input_hint_found = false
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(fake_buf, -1, 0, -1, { details = true })) do
  local details = mark[4]
  local text = details.virt_text
      and table.concat(vim.tbl_map(function(chunk)
        return chunk[1]
      end, details.virt_text))
    or ""
  if text == "<S-Tab> plain" then
    input_hint_found = details.virt_text_win_col == input_width - vim.api.nvim_strwidth("<S-Tab> plain") - 4
      and details.virt_text[1][2] == "Comment"
      and details.virt_text[2][2] == "Comment"
  end
end

assert_truthy(input_hint_found, "grep mode hint renders at a fixed distance from the input right edge")

fake_input.picker.opts.snacks_fff.grep_mode = "regex"
input.render(fake_input)
local regex_hint_found = false
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(fake_buf, -1, 0, -1, { details = true })) do
  local details = mark[4]
  local text = details.virt_text
      and table.concat(vim.tbl_map(function(chunk)
        return chunk[1]
      end, details.virt_text))
    or ""
  if text == "<S-Tab> regex" then
    regex_hint_found = details.virt_text[1][2] == "DiagnosticInfo" and details.virt_text[2][2] == "DiagnosticInfo"
  end
end
assert_truthy(regex_hint_found, "regex mode hint uses the original fff regex highlight")

fake_input.picker.opts.snacks_fff.grep_mode = "fuzzy"
input.render(fake_input)
local fuzzy_hint_found = false
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(fake_buf, -1, 0, -1, { details = true })) do
  local details = mark[4]
  local text = details.virt_text
      and table.concat(vim.tbl_map(function(chunk)
        return chunk[1]
      end, details.virt_text))
    or ""
  if text == "<S-Tab> fuzzy" then
    fuzzy_hint_found = details.virt_text[1][2] == "DiagnosticHint" and details.virt_text[2][2] == "DiagnosticHint"
  end
end
assert_truthy(fuzzy_hint_found, "fuzzy mode hint uses the original fff fuzzy highlight")

local original_grep_for_empty = backend.grep
backend.grep = function()
  return {}, "C:/repo"
end
local empty_grep_items = grep_source.finder({ snacks_fff = { grep_mode = "plain" } }, { filter = { search = "" } })
backend.grep = original_grep_for_empty
assert_equal(empty_grep_items[1].fff_kind, "message", "empty grep renders original fff usage tips")
assert_equal(
  empty_grep_items[1].text,
  "  Start typing to search file contents...",
  "empty grep first tip mirrors original fff text"
)
assert_equal(
  empty_grep_items[2].text,
  '  "pattern *.rs"    search only in Rust files',
  "empty grep extension filter tip mirrors original fff text"
)

local original_grep = backend.grep
local original_find_files = backend.find_files
backend.grep = function()
  return {}, "C:/repo"
end
backend.find_files = function()
  return {
    { relative_path = "lua/plugins/fff.lua", name = "fff.lua", path = "lua/plugins/fff.lua" },
  }, "C:/repo"
end

local fallback_opts = { snacks_fff = { grep_mode = "plain" } }
local fallback_items = grep_source.finder(fallback_opts, { filter = { search = "missing content" } })
backend.grep = original_grep
backend.find_files = original_find_files

assert_equal(#fallback_items, 1, "grep no-results falls back to file suggestions")
assert_equal(fallback_items[1].fff_kind, "file_suggestion", "fallback item is explicitly a file suggestion")
assert_truthy(fallback_items[1].fff_headers, "fallback file suggestion owns a visual suggestion header")
assert_equal(
  fallback_items[1].fff_headers[2].text,
  "  No results, try <S-Tab> to fuzzy search",
  "fallback suggestion header mirrors original fff text"
)
assert_equal(
  fallback_items[1].fff_headers[2].fff_message_hl,
  "WarningMsg",
  "fallback suggestion header uses original fff highlight"
)

print("snacks-fff tests passed")
