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

require('markdowny').setup()
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

## Keymaps

All in visual mode

- `<C-k>` add link to visually selected text
- `<C-b>` toggle visually selected text bold
- `<C-i>` toggle visually selected text italic

## Custom setup

Alternatively to default keymaps you can use custom keymaps. Make sure to keymap to a string, not lua function. Defaults

```lua
vim.keymap.set('v', '<C-b>', ":lua require('markdowny').bold()<cr>", { buffer = 0 })
vim.keymap.set('v', '<C-i>', ":lua require('markdowny').italic()<cr>", { buffer = 0 })
vim.keymap.set('v', '<C-k>', ":lua require('markdowny').link()<cr>", { buffer = 0 })
```

## Acknowledgments

This plugin uses `vim.ui.input` to prompt for link's href, to have it in a floating window, like in the demo above, you can use [dressing.nvim](https://github.com/stevearc/dressing.nvim).
