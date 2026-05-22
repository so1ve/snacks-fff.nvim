# snacks-fff.nvim

Use [snacks.nvim](https://github.com/folke/snacks.nvim)'s picker UI with [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim)'s fast file and grep backend.

This plugin keeps fff.nvim responsible for indexing, frecency, git-aware file search, and content grep, while rendering the interactive picker through Snacks. The goal is to recreate the original fff picker experience with Snacks picker APIs, while keeping Snacks' ergonomics and excellent default keymaps.

> [!WARNING]
> Most of this project was written by AI. **DO NOT USE** if you are worried about AI-generated slop.
>
> The primary model used was GPT-5.5.

## Why

fff.nvim has an excellent backend, but you may prefer Snacks picker for layout, preview, actions, and integration with an existing Snacks-based Neovim setup.

snacks-fff.nvim bridges that gap by recreating fff's original picker behavior on top of Snacks picker APIs. It preserves the important fff UI details:

- file rows with fff-style git signs, icons, names, directories, and optional frecency scores
- live grep rows grouped by file, with non-selectable visual file headers above selectable matches
- plain, regex, and fuzzy grep modes using fff's `cycle_grep_modes` key
- a right-aligned input hint like `<S-Tab> plain`
- match highlighting that mirrors Snacks preview search highlighting
- no-results grep fallback that suggests matching files

## Comparison with `fff-snacks.nvim`

There is already an existing plugin named [`fff-snacks.nvim`](https://github.com/madmaxieee/fff-snacks.nvim), so this project uses the reversed name `snacks-fff.nvim` and the Lua module `require("snacks-fff")` to avoid a module/repository name collision.

Both projects use fff.nvim as the search backend and Snacks picker as the UI. The differences are in how much of fff's original picker behavior they try to reproduce:

| Difference | `fff-snacks.nvim` | `snacks-fff.nvim` |
| --- | --- | --- |
| Naming/API | `require("fff-snacks")`, `:FFFSnacks` | `require("snacks-fff")`, `:SnacksFff` |
| UI restoration goal | Lightweight fff-backed Snacks source | Recreate the original fff picker experience with Snacks picker APIs |
| Grep grouping | Presents fff grep results in Snacks | Recreates fff-like file group headers as visual-only rows above selectable matches |
| Header selection behavior | Standard Snacks item flow, similar to `Snacks.picker.grep` | Headers are not picker items; clicking a header maps to its owning match to avoid preview flicker |
| Match display | fff-powered grep item formatting | Fixed-width left-aligned `:line:col`, Treesitter syntax chunks, and `SnacksPickerSearch` match overlays matching preview colors |
| Mode hint | Supports grep mode cycling | Keeps a fixed-right input hint like `<S-Tab> plain` and removes Snacks' native totals virtual text to avoid overlap |
| No-results behavior | Basic fff/Snacks fallback behavior | Adds fff-style `No results, try <S-Tab> to fuzzy search` header plus file suggestions |

Use `fff-snacks.nvim` if you want the smaller existing adapter. Use this plugin if you want the original fff picker experience rebuilt on Snacks, without giving up Snacks' easy configuration and default keymap presets.

## Requirements

- Neovim 0.10+
- [snacks.nvim](https://github.com/folke/snacks.nvim)
- [fff.nvim](https://github.com/dmtrKovalenko/fff.nvim)

## Installation

### `lazy.nvim`

```lua
{
  "so1ve/snacks-fff.nvim",
  dependencies = {
    "folke/snacks.nvim",
    {
      "dmtrKovalenko/fff.nvim",
      build = function()
        require("fff.download").download_or_build_binary()
      end,
    },
  },
}
```

## Usage

```lua
require("snacks-fff").find_files()
require("snacks-fff").live_grep()
require("snacks-fff").grep_word()
require("snacks-fff").find_files_in_dir(vim.fn.stdpath("config"))
```

Example keymaps:

```lua
vim.keymap.set("n", "<leader>ff", function()
  require("snacks-fff").find_files()
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>fg", function()
  require("snacks-fff").live_grep()
end, { desc = "Live grep" })
```

The plugin also provides a command:

```vim
:SnacksFff find_files
:SnacksFff live_grep
:SnacksFff fuzzy
:SnacksFff grep_word
```

## Configuration

```lua
require("snacks-fff").setup({
  find_files = {
    -- Any Snacks picker option accepted by snacks.picker.pick().
    layout = { preset = "vertical" },
  },

  live_grep = {
    -- Uses fff grep modes and cycling order.
    grep_modes = { "plain", "regex", "fuzzy" },

    -- Right padding for the input hint, e.g. `<S-Tab> plain`.
    snacks_fff = {
      grep_mode_hint_right_padding = 4,
      show_grep_mode_hint = true,
      match_hl = "SnacksPickerSearch",
    },
  },

  -- grep_word falls back to live_grep options unless overridden.
  grep_word = {},
})
```

You can also pass options at call time:

```lua
require("snacks-fff").find_files({ cwd = vim.fn.stdpath("config") })
require("snacks-fff").live_grep({ grep_modes = { "fuzzy", "plain" } })
require("snacks-fff").live_grep({ query = "snacks" })
```

## API

### `setup(opts?)`

Stores default picker options.

```lua
require("snacks-fff").setup({})
```

### `find_files(opts?)`

Open a Snacks picker backed by `fff.file_picker.search_files_paginated()`.

```lua
require("snacks-fff").find_files({ cwd = vim.uv.cwd() })
```

### `live_grep(opts?)`

Open a Snacks picker backed by `fff.grep.search()`.

```lua
require("snacks-fff").live_grep({ grep_modes = { "plain", "regex", "fuzzy" } })
```

### `grep_word(opts?)`

Open live grep prefilled with the word under the cursor.

```lua
require("snacks-fff").grep_word()
```

### `find_files_in_dir(directory, opts?)`

Open file search in a specific directory and update fff's indexing root for that picker.

```lua
require("snacks-fff").find_files_in_dir(vim.fn.stdpath("config"))
```

## Notes

This plugin intentionally uses a few internal APIs from both dependencies:

- `fff.file_picker.search_files_paginated()`
- `fff.grep.search()`
- `fff.core.ensure_initialized().restart_index_in_path()`
- `fff.treesitter_hl`
- `snacks.picker.core.input`
- `snacks.picker.core.list`

The Snacks list/input patches are scoped to the `snacks_fff_grep` source and installed once per Neovim session. Pin Snacks and fff.nvim if you need maximum stability.

## Development

```bash
stylua lua plugin tests
nvim --headless -u NONE -l tests/snacks-fff_spec.lua
```

## 📝 License

[MIT](./LICENSE). Made with ❤️ by [Ray](https://github.com/so1ve)
