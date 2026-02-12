local M = {}

---@alias Position [ integer, integer ]

---@class Selection
---@field first_pos Position The first position of the selection.
---@field last_pos Position The last position of the selection.

-- Gets a line from the buffer, 1-indexed.
---@param line_num integer The number of the line to be retrieved.
---@return string @The contents of the line that was retrieved.
---@nodiscard
local get_line = function(line_num)
    return vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
end

-- Delete a line from the buffer, 1-indexed.
---@param line_num integer The number of the line to be deleted.
local delete_line = function(line_num)
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, true, {})
end

-- Adds some text into the buffer at a given position.
---@param pos Position The position to be inserted at.
---@param text string[] The text to be added.
local insert_text = function(pos, text)
    pos[2] = math.min(pos[2], #get_line(pos[1]) + 1)
    vim.api.nvim_buf_set_text(0, pos[1] - 1, pos[2] - 1, pos[1] - 1, pos[2] - 1, text)
end

-- Sets the position of the cursor, 1-indexed.
---@param pos Position The given position.
local set_curpos = function(pos)
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] - 1 })
end

-- Gets the row and column for a mark, 1-indexed, if it exists, returns nil otherwise.
---@param mark string The mark whose position will be returned.
---@return Position @The position of the mark.
---@nodiscard
local get_mark = function(mark)
    local position = vim.api.nvim_buf_get_mark(0, mark)
    return { position[1], position[2] + 1 }
end

-- Sets the position of a mark, 1-indexed.
---@param mark string The mark whose position will be returned.
---@param position Position? The position that the mark should be set to.
local set_mark = function(mark, position)
    if position then
        vim.api.nvim_buf_set_mark(0, mark, position[1], position[2] - 1, {})
    end
end

-- Gets the position of the first byte of a character, according to the UTF-8 standard.
---@param pos Position The position of any byte in the character.
---@return Position @The position of the first byte of the character.
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
---@param pos Position? The position of the beginning of the character.
---@return Position? @The position of the last byte of the character.
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

-- Check if text has surround markers at both ends.
---@param text string The text to check.
---@param before string The marker that should appear at the start.
---@param after string The marker that should appear at the end.
---@return boolean @True if text has both markers.
---@nodiscard
local has_surround_markers = function(text, before, after)
    if #text < #before + #after then
        return false
    end
    return text:sub(1, #before) == before and text:sub(-#after) == after
end

-- Remove surround markers from text.
---@param text string The text to remove markers from.
---@param before string The marker to remove from the start.
---@param after string The marker to remove from the end.
---@return string @The text with markers removed.
---@nodiscard
local remove_surround_markers = function(text, before, after)
    if not has_surround_markers(text, before, after) then
        return text
    end
    return text:sub(#before + 1, -#after - 1)
end

-- Add surround markers to text.
---@param text string The text to add markers to.
---@param before string The marker to add at the start.
---@param after string The marker to add at the end.
---@return string @The text with markers added.
---@nodiscard
local add_surround_markers = function(text, before, after)
    return before .. text .. after
end

-- Extract text from visual selection based on mode.
---@param start_pos Position The start position of the selection.
---@param end_pos Position The end position of the selection.
---@param is_block boolean Whether this is visual block mode.
---@param block_left_col integer|nil Left byte column for block mode.
---@param block_right_col integer|nil Right byte column for block mode.
---@return string[] @Array of text lines from the selection.
---@nodiscard
local extract_visual_text = function(start_pos, end_pos, is_block, block_left_col, block_right_col)
    local text = {}
    if is_block then
        local col_start = block_left_col or start_pos[2]
        local col_end = block_right_col or end_pos[2]

        for i = start_pos[1], end_pos[1] do
            local line = get_line(i)
            local line_length = #line

            if col_start > line_length then
                table.insert(text, '')
            elseif col_end > line_length then
                table.insert(text, line:sub(col_start, line_length))
            else
                table.insert(text, line:sub(col_start, col_end))
            end
        end
    else
        -- Normal visual mode
        text = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2] - 1, end_pos[1] - 1, end_pos[2], {})
    end
    return text
end

-- Get column boundaries for a line in the selection.
---@param line_num integer The line number (1-indexed).
---@param start_pos Position The start position of the selection.
---@param end_pos Position The end position of the selection.
---@param is_block boolean Whether this is visual block mode.
---@param block_left_col integer|nil Left byte column for block mode.
---@param block_right_col integer|nil Right byte column for block mode.
---@return integer, integer @Column start and end positions.
---@nodiscard
local get_column_bounds = function(line_num, start_pos, end_pos, is_block, block_left_col, block_right_col)
    if is_block and block_left_col and block_right_col then
        return block_left_col, block_right_col
    elseif is_block then
        return start_pos[2], end_pos[2]
    else
        local col_start = (line_num == start_pos[1]) and start_pos[2] or 1
        local col_end = (line_num == end_pos[1]) and end_pos[2] or #get_line(line_num)
        return col_start, col_end
    end
end

-- Apply a text transformation to a line in the buffer.
---@param line_num integer The line number (1-indexed).
---@param col_start integer The starting column (1-indexed).
---@param col_end integer The ending column (1-indexed, may extend beyond line length).
---@param replacement_text string The text to replace the selection with.
---@return integer @The new end column position.
---@nodiscard
local apply_line_transformation = function(line_num, col_start, col_end, replacement_text)
    local full_line = get_line(line_num)
    local line_length = #full_line
    local prefix = full_line:sub(1, col_start - 1)
    local suffix = col_end < line_length and full_line:sub(col_end + 1) or ''
    local new_line = prefix .. replacement_text .. suffix
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, {new_line})
    return col_start + #replacement_text - 1
end

-- Check if all lines in an array have surround markers.
---@param text string[] Array of text lines to check.
---@param before string The marker that should appear at the start of each line.
---@param after string The marker that should appear at the end of each line.
---@return boolean @True if all lines have both markers.
---@nodiscard
local check_all_lines_have_surround = function(text, before, after)
    for _, line in ipairs(text) do
        if not has_surround_markers(line, before, after) then
            return false
        end
    end
    return true
end

-- Exit visual mode if still active, capturing block boundaries for block mode.
-- Must be called from <Cmd> mappings (before visual mode exits) to get true
-- block columns. Neovim caps mark columns to line length, so we use
-- winsaveview().curswant to preserve the true cursor column on short lines.
---@return { block_info: table|nil, visual_mode: string|nil }
local exit_visual_if_active = function()
    local mode = vim.fn.mode()
    local result = { block_info = nil, visual_mode = nil }

    if mode:sub(1, 1) == '\22' then
        local anchor = vim.fn.getpos('v')
        local cursor_line = vim.fn.line('.')
        local curswant = vim.fn.winsaveview().curswant
        local anchor_col = anchor[3] -- 1-indexed byte column
        local cursor_col = curswant + 1 -- Convert 0-indexed to 1-indexed

        -- Handle $ (MAXCOL) - curswant will be a very large number
        if cursor_col > 10000 then
            local start_line = math.min(anchor[2], cursor_line)
            local end_line = math.max(anchor[2], cursor_line)
            local max_len = 0
            for i = start_line, end_line do
                max_len = math.max(max_len, #get_line(i))
            end
            cursor_col = max_len
        end

        result.block_info = {
            start_line = math.min(anchor[2], cursor_line),
            end_line = math.max(anchor[2], cursor_line),
            left_col = math.min(anchor_col, cursor_col),
            right_col = math.max(anchor_col, cursor_col),
        }
        result.visual_mode = '\22'
    elseif mode == 'v' or mode == 'V' then
        result.visual_mode = mode
    end

    -- Exit visual mode if active (sets the '<' and '>' marks)
    if result.visual_mode then
        local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
        vim.api.nvim_feedkeys(esc, 'nx', false)
    end

    return result
end

-- Applies surround markers before and after selected text in the current buffer.
-- Supports three modes:
--   1. Single-line: Wraps entire selection with markers
--   2. Multi-line visual: Adds markers to the beginning/end of each selected line
--   3. Visual block: Adds markers to the beginning/end of the block column range on each line
-- If `remove` is true and all selected text already has markers, removes them instead (toggle behavior).
---@param before string The string to insert before the selected text.
---@param after string The string to insert after the selected text.
---@param remove boolean|nil Remove surround if possible (default true).
---@param block_info table|nil Captured block boundaries from exit_visual_if_active().
local inline_surround = function(before, after, remove, block_info)
    local visual_mode = vim.fn.visualmode()
    local is_block = visual_mode == '\22'

    local start_pos = get_first_byte(get_mark('<'))
    local end_pos = get_last_byte(get_mark('>'))

    -- Validate marks exist
    if start_pos == nil or end_pos == nil then
        return
    end

    -- In visual block mode, use captured block info for true boundaries
    local block_left_col, block_right_col
    if is_block and block_info then
        block_left_col = block_info.left_col
        block_right_col = block_info.right_col
        start_pos[1] = block_info.start_line
        end_pos[1] = block_info.end_line
    end

    -- Manually count chars of last selected line in V-LINE mode due
    -- to '>' reaching max int value. Address if it's neovim bug.
    if vim.fn.visualmode() == 'V' then
        end_pos[2] = #get_line(end_pos[1])
    end

    -- Validate selection range
    if start_pos[1] > end_pos[1] or (start_pos[1] == end_pos[1] and start_pos[2] > end_pos[2]) then
        if not is_block then
            vim.notify('[markdowny.nvim] Invalid selection range', vim.log.levels.WARN)
            return
        end
    end

    remove = vim.F.if_nil(remove, true)

    local is_single_line = start_pos[1] == end_pos[1]

    if is_single_line and not is_block then
        -- Single-line mode: wrap entire selection with markers
        local text = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2] - 1, end_pos[1] - 1, end_pos[2], {})
        local selected_text = text[1]
        local is_removing = has_surround_markers(selected_text, before, after) and remove

        if is_removing then
            local transformed_text = remove_surround_markers(selected_text, before, after)
            vim.api.nvim_buf_set_text(0, start_pos[1] - 1, start_pos[2] - 1, end_pos[1] - 1, end_pos[2], {transformed_text})
            end_pos[2] = end_pos[2] - #before - #after
        else
            insert_text(start_pos, { before })
            end_pos[2] = end_pos[2] + #before + 1
            insert_text(end_pos, { after })
            end_pos[2] = end_pos[2] + #after - 1
        end
    else
        -- Multi-line mode: add markers to beginning/end of each line
        local text = extract_visual_text(start_pos, end_pos, is_block, block_left_col, block_right_col)

        -- In block mode, we need to check markers on trimmed content
        local is_removing
        if is_block then
            is_removing = true
            if remove then
                for _, line in ipairs(text) do
                    local trimmed = line:match('^%s*(.-)%s*$')
                    if not has_surround_markers(trimmed, before, after) then
                        is_removing = false
                        break
                    end
                end
            else
                is_removing = false
            end
        else
            is_removing = remove and check_all_lines_have_surround(text, before, after)
        end

        for i = start_pos[1], end_pos[1] do
            local line_idx = i - start_pos[1] + 1
            local col_start, col_end =
                get_column_bounds(i, start_pos, end_pos, is_block, block_left_col, block_right_col)
            local selected_text = text[line_idx]
            local transformed_text

            if is_block then
                -- In block mode, preserve leading/trailing whitespace outside markers
                local leading_ws = selected_text:match('^(%s*)')
                local trailing_ws = selected_text:match('(%s*)$')
                local content = selected_text:match('^%s*(.-)%s*$')

                if is_removing then
                    content = remove_surround_markers(content, before, after)
                else
                    content = add_surround_markers(content, before, after)
                end

                transformed_text = leading_ws .. content .. trailing_ws
            else
                if is_removing then
                    transformed_text = remove_surround_markers(selected_text, before, after)
                else
                    transformed_text = add_surround_markers(selected_text, before, after)
                end
            end

            local new_end_col = apply_line_transformation(i, col_start, col_end, transformed_text)
            if i == end_pos[1] then
                end_pos[2] = new_end_col
            end
        end
    end

    set_mark('>', end_pos)
end

-- Applies a specified surround text `before` and `after` text to the selected newline within the current buffer.
---@param before string The string to insert before the selected text.
---@param after string The string to insert after the selected text.
---@param remove boolean|nil Remove surround if possible (default true).
local newline_surround = function(before, after, remove)
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

    remove = vim.F.if_nil(remove, true)

    local text = vim.api.nvim_buf_get_text(0, s[1] - 1, s[2] - 1, e[1] - 1, e[2], {})

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

function M.bold()
    local ctx = exit_visual_if_active()
    inline_surround('**', '**', nil, ctx.block_info)
end

function M.italic()
    local ctx = exit_visual_if_active()
    inline_surround('_', '_', nil, ctx.block_info)
end

function M.code()
    local ctx = exit_visual_if_active()
    local visual_mode = ctx.visual_mode or vim.fn.visualmode()
    if visual_mode == 'V' then
        newline_surround('```', '```')
    else
        inline_surround('`', '`', nil, ctx.block_info)
    end
end

function M.link()
    local ctx = exit_visual_if_active()
    vim.ui.input({ prompt = 'Href:' }, function(href)
        if href == nil then
            return
        end
        inline_surround('[', '](' .. href .. ')', false, ctx.block_info)
    end)
end

function M.inline_code()
    vim.notify(
        "[markdowny.nvim] 'inline_code' has been deprecated. Please use 'code' function instead.",
        vim.log.levels.WARN
    )
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_autocmd('FileType', {
        desc = 'markdowny.nvim keymaps',
        pattern = opts.filetypes or {'markdown', 'gitcommit', 'hgcommit'},
        callback = function()
            vim.keymap.set('v', '<C-b>', "<Cmd>lua require('markdowny').bold()<CR>", { buffer = 0, silent = true })
            vim.keymap.set('v', '<C-i>', "<Cmd>lua require('markdowny').italic()<CR>", { buffer = 0, silent = true })
            vim.keymap.set('v', '<C-k>', "<Cmd>lua require('markdowny').link()<CR>", { buffer = 0, silent = true })
            vim.keymap.set('v', '<C-e>', "<Cmd>lua require('markdowny').code()<CR>", { buffer = 0, silent = true })
        end,
    })
end

return M
