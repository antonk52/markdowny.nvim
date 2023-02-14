# markdowny.nvim

Neovim plugin for markdown like keybindings. Similar to notion, discord, slack etc

![plugin demo](https://user-images.githubusercontent.com/5817809/211911652-fe0c1d26-1dd0-4832-b948-e685067bb78b.gif)

## Install

```lua
-- packer
use {
    'antonk52/markdowny.nvim',
    config = function()
        require('markdowny').setup()
    end
}
```

```lua
-- lazy.nvim
{
    'antonk52/markdowny.nvim'
    config = function()
        require('markdowny').setup()
    end
}
```

## Setup Options

- `filetypes` a table of filetypes to add markdowny keymaps. Default `{'markdown'}`

```lua
require('markdowny').setup({filetypes = {'markdown', 'txt'}})
```

## Default keymaps

All in visual mode

- `<C-k>`: Adds a link to visually selected text.
- `<C-b>`: Toggles visually selected text to bold.
- `<C-i>`: Toggles visually selected text to italic.
- `<C-e>`: Toggles visually selected text to inline code, and **V-LINE** selected text to a multiline code block.

## Custom setup

Alternatively to default keymaps you can use custom keymaps without calling `setup` function, make sure to map to a string rather than a Lua function. Here are the defaults:

```lua
vim.keymap.set('v', '<C-b>', ":lua require('markdowny').bold()<cr>", { buffer = 0 })
vim.keymap.set('v', '<C-i>', ":lua require('markdowny').italic()<cr>", { buffer = 0 })
vim.keymap.set('v', '<C-k>', ":lua require('markdowny').link()<cr>", { buffer = 0 })
vim.keymap.set('v', '<C-e>', ":lua require('markdowny').code()<cr>", { buffer = 0 })
```

To apply the keymaps to specific filetypes, use `autocmd`:

```lua
vim.api.nvim_create_autocmd('FileType', {
    desc = 'markdowny.nvim keymaps',
    pattern = { 'markdown' },
    callback = function()
        -- add custom keymaps here
    end,
})
```

## Acknowledgments

This plugin uses `vim.ui.input` to prompt for link's href, to have it in a floating window, like in the demo above, you can use [dressing.nvim](https://github.com/stevearc/dressing.nvim).
