# markdowny.nvim

Neovim plugin for markdown like keybindings. Similar to notion, discord, slack etc

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
-- lazy.nvim

{
    'antonk52/markdowny.nvim'
    config = function()
        require('markdowny').setup()
    end
}
```

## Setup Options

- `filetypes` a table of filetypes to add the markdowny keybindings for. Default `{'markdown'}`

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
