local M = {}

--[====================================================================================================================[
                                            Buffer contents helper functions
--]====================================================================================================================]

-- Gets a line from the buffer, 1-indexed.
---@param line_num integer The number of the line to be retrieved.
---@return string @The contents of the line that was retrieved.
---@nodiscard
local get_line = function(line_num)
    return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
end

-- Delete a line from the buffer, 1-indexed.
---@param line_num integer The number of the line to be deleted.
---@nodiscard
local delete_line = function(line_num)
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, {})
end

-- Gets a selection of text from the buffer.
---@param selection selection The selection of text to be retrieved.
---@return text @The text from the buffer.
---@nodiscard
local get_text = function(selection)
    local first_pos, last_pos = selection.first_pos, selection.last_pos
    last_pos[2] = math.min(last_pos[2], #get_line(last_pos[1]))
    return vim.api.nvim_buf_get_text(0, first_pos[1] - 1, first_pos[2] - 1, last_pos[1] - 1, last_pos[2], {})
end

-- Adds some text into the buffer at a given position.
---@param pos position The position to be inserted at.
---@param text text The text to be added.
local insert_text = function(pos, text)
    pos[2] = math.min(pos[2], #get_line(pos[1]) + 1)
    vim.api.nvim_buf_set_text(0, pos[1] - 1, pos[2] - 1, pos[1] - 1, pos[2] - 1, text)
end

-- Replaces a given selection with a set of lines.
---@param selection? selection The given selection.
---@param text text The given text to replace the selection.
local change_text = function(selection, text)
    if not selection then
        return
    end
    local first_pos, last_pos = selection.first_pos, selection.last_pos
    vim.api.nvim_buf_set_text(0, first_pos[1] - 1, first_pos[2] - 1, last_pos[1] - 1, last_pos[2], text)
end

--[====================================================================================================================[
                                                 Cursor helper functions
--]====================================================================================================================]

-- Sets the position of the cursor, 1-indexed.
---@param pos position? The given position.
local set_curpos = function(pos)
    if not pos then
        return
    end
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] - 1 })
end

--[====================================================================================================================[
                                                 Mark helper functions
--]====================================================================================================================]

-- Gets the row and column for a mark, 1-indexed, if it exists, returns nil otherwise.
---@param mark string The mark whose position will be returned.
---@return position @The position of the mark.
---@nodiscard
local get_mark = function(mark)
    local position = vim.api.nvim_buf_get_mark(0, mark)
    return { position[1], position[2] + 1 }
end

-- Sets the position of a mark, 1-indexed.
---@param mark string The mark whose position will be returned.
---@param position position? The position that the mark should be set to.
local set_mark = function(mark, position)
    if position then
        vim.api.nvim_buf_set_mark(0, mark, position[1], position[2] - 1, {})
    end
end

--[====================================================================================================================[
                                             Byte indexing helper functions
--]====================================================================================================================]

-- Gets the position of the first byte of a character, according to the UTF-8 standard.
---@param pos position The position of any byte in the character.
---@return position @The position of the first byte of the character.
---@nodiscard
local get_first_byte = function(pos)
    local byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
    if not byte then
        return pos
    end
    -- See https://en.wikipedia.org/wiki/UTF-8#Encoding
    while byte >= 0x80 and byte < 0xc0 do
        pos[2] = pos[2] - 1
        byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
    end
    return pos
end

-- Gets the position of the last byte of a character, according to the UTF-8 standard.
---@param pos position? The position of the beginning of the character.
---@return position? @The position of the last byte of the character.
---@nodiscard
local get_last_byte = function(pos)
    if not pos then
        return nil
    end

    local byte = string.byte(get_line(pos[1]):sub(pos[2], pos[2]))
    if not byte then
        return pos
    end
    -- See https://en.wikipedia.org/wiki/UTF-8#Encoding
    if byte >= 0xf0 then
        pos[2] = pos[2] + 3
    elseif byte >= 0xe0 then
        pos[2] = pos[2] + 2
    elseif byte >= 0xc0 then
        pos[2] = pos[2] + 1
    end
    return pos
end

--[====================================================================================================================[
                                                 Surround helper functions
--]====================================================================================================================]

-- Parse optional argument.
---@param opts table|nil optional keyword arguments table
---@param key string key of argumnet
---@param default any default value
---@return any @The value of parameter.
local parse_arg = function(opts, key, default)
    if opts and opts[key] ~= nil then
        return opts[key]
    else
        return default
    end
end

-- Applies a specified surround text `before` and `after` at a selected within the current buffer.
---@param before string The string to insert before the selected text.
---@param after string The string to insert after the selected text.
---@param opts table|nil Optional keyword arguments:
--- - remove: Remove surround if possible (default true).
local inline_surround = function(before, after, opts)
    local s = get_first_byte(get_mark('<'))
    local e = get_last_byte(get_mark('>'))

    if s == nil or e == nil then
        return
    end

    -- Manually count chars of last selected line in V-LINE mode due
    -- to '>' reaching max int value. Address if it's neovim bug.
    if vim.fn.visualmode() == 'V' then
        e[2] = #get_line(e[1])
    end

    -- Parsing Options
    local remove = parse_arg(opts, 'remove', true)

    local selection = { first_pos = s, last_pos = e }
    local text = get_text(selection)

    local first = text[1]:sub(1, #before) == before
    local last = text[#text]:sub(-#after) == after

    local is_removing = first and last and remove
    local is_sameline = s[1] == e[1]

    if is_removing then
        text[1] = text[1]:sub(#before + 1, -1)
        text[#text] = text[#text]:sub(1, -#after - 1)

        change_text(selection, text)

        if is_sameline then
            e[2] = e[2] - #before - #after
        else
            e[2] = e[2] - #after
        end
    else
        insert_text(s, { before })
        e[2] = e[2] + 1

        if is_sameline then
            e[2] = e[2] + #before
        end

        insert_text(e, { after })
        e[2] = e[2] + #after - 1
    end

    set_mark('>', e)
end

-- Applies a specified surround text `before` and `after` text to the selected newline within the current buffer.
---@param before string The string to insert before the selected text.
---@param after string The string to insert after the selected text.
---@param opts table|nil Optional keyword arguments:
--- - remove: Remove surround if possible (default true).
local newline_surround = function(before, after, opts)
    local s = get_first_byte(get_mark('<'))
    local e = get_last_byte(get_mark('>'))

    if s == nil or e == nil then
        return
    end

    -- Manually count chars of last selected line in V-LINE mode due
    -- to '>' reaching max int value. Address if it's neovim bug.
    if vim.fn.visualmode() == 'V' then
        e[2] = #get_line(e[1])
    end

    -- Parsing Options
    local remove = parse_arg(opts, 'remove', true)

    local selection = { first_pos = s, last_pos = e }
    local text = get_text(selection)

    local first = text[1] == before
    local last = text[#text] == after

    local is_removing = first and last and remove

    if is_removing then
        delete_line(s[1])
        e[1] = e[1] - 1

        delete_line(e[1])
        e[1] = e[1] - 1

        set_mark('>', { e[1], #text[#text - 1] - 1 })
        set_curpos({ e[1], 1 })
    else
        insert_text(s, { before, '' })
        s = { s[1], 1 }
        set_mark('<', s)

        e = { e[1] + 1, e[2] + 1 }
        insert_text(e, { '', after })
        e = { e[1] + 1, #after }
        set_mark('>', e)

        set_curpos({ e[1] - 1, 1 })
    end
end
--[====================================================================================================================[
                                               Markdown surround functions
--]====================================================================================================================]

function M.bold()
    inline_surround('**', '**')
end

function M.italic()
    inline_surround('_', '_')
end

function M.code()
    if vim.fn.visualmode() == 'V' then
        newline_surround('```', '```')
    else
        inline_surround('`', '`')
    end
end

function M.link()
    vim.ui.input({ prompt = 'Href:' }, function(href)
        if href == nil then
            return
        end
        inline_surround('[', '](' .. href .. ')', { remove = false })
    end)
end

function M.inline_code()
    vim.notify(
        "[markdowny.nvim] 'inline_code' has been deprecated. Please use 'code' function instead.",
        vim.log.levels.WARN
    )
end

--[====================================================================================================================[
                                                   Setup Function
--]====================================================================================================================]

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_autocmd('FileType', {
        desc = 'markdowny.nvim keymaps',
        pattern = opts.filetypes or 'markdown',
        callback = function()
            vim.keymap.set('v', '<C-b>', ":lua require('markdowny').bold()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-i>', ":lua require('markdowny').italic()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-k>', ":lua require('markdowny').link()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-e>', ":lua require('markdowny').code()<cr>", { buffer = 0 })
        end,
    })
end

return M
