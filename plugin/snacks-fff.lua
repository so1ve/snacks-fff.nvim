if vim.g.loaded_snacks_fff == 1 then
  return
end
vim.g.loaded_snacks_fff = 1

local commands = {
  find_files = function()
    require("snacks-fff").find_files()
  end,
  live_grep = function()
    require("snacks-fff").live_grep()
  end,
  fuzzy = function()
    require("snacks-fff").live_grep({ grep_modes = { "fuzzy", "plain", "regex" } })
  end,
  grep_word = function()
    require("snacks-fff").grep_word()
  end,
}

vim.api.nvim_create_user_command("SnacksFff", function(command)
  local subcommand = command.args ~= "" and command.args or "find_files"
  local handler = commands[subcommand]

  if not handler then
    vim.notify("Unknown SnacksFff command: " .. subcommand, vim.log.levels.ERROR)
    return
  end

  handler()
end, {
  nargs = "?",
  complete = function()
    return vim.tbl_keys(commands)
  end,
})
