local M = {}

---@private
--- Counts if the Cyrillic character at the given index of
--- the string is double width.
---
---@param str (string) The input string
---@param idx (number) The index of the character to check
---
---@return (boolean) `true` if the character is double width, `false` otherwise
local function __is_double_char(str, idx)
    local char = str:sub(idx, idx + 1)
    local display_width = vim.fn.strdisplaywidth(char)

    return #char ~= display_width
end

---@private
--- Update the '>' mark, which represents the end column
--- position of the selection, in visual mode after adding or
--- removing a surround, enabling the region to be reselected
--- using the 'gv' command.
---
---@param line (number) The line number of the mark to update.
---@param col  (number) The column/row number of the mark to update.
local function __update_end_selection_mark(line, col)
    vim.api.nvim_buf_set_mark(0, '>', line, col, {})
end

---@private
--- Update the '<' mark, which represents the start column
--- position of the selection, in visual mode after adding or
--- removing a surround, enabling the region to be reselected
--- using the 'gv' command.
---
---@param line (number) The line number of the mark to update.
---@param col  (number) The column/row number of the mark to update.
local function __update_start_selection_mark(line, col)
    vim.api.nvim_buf_set_mark(0, '<', line, col, {})
end

---@private
--- Gets a single line from the current buffer.
---
---@param line (number) The line number of current buffer.
local function __buf_get_line(line)
    return vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
end

---@private
--- Replace a lines to the current buffer.
---
---@param line (number) line index from current buffer.
---@param replacement (table) Array of lines to use as replacement
local function __buf_set_line(line, replacement)
    vim.api.nvim_buf_set_lines(0, line - 1, line, true, replacement)
end

---@private
--- Applies a specified surround text `before` and `after` at
--- a specified position `start_pos` and `end_pos` within the
--- current buffer.
---
---@param start_pos (table) The start position of text:
---  - line: (number) Line index
---  - col: (number) Column/row index
---@param end_pos (table) The end position of text:
---  - line: (number) Line index
---  - col: (number) Column/row index
---@param before (string) The string to insert before the selected text.
---@param after (string) The string to insert after the selected text.
---@param opts (nil|table) Optional keyword arguments:
---  - newline: Add surrounds string "before" and "after" to newline
--              In multi-line selection
local function __toggle_surround(start_pos, end_pos, before, after, opts)
    local start_line_txt = __buf_get_line(start_pos.line)
    local end_line_txt = __buf_get_line(end_pos.line)

    local is_same_line = start_pos.line == end_pos.line

    local first = start_line_txt:sub(start_pos.col + 1, start_pos.col + #before) == before
    local last = end_line_txt:sub(end_pos.col + 2 - #after, end_pos.col + 1) == after

    local is_removing = first and last

    local idx_end = end_pos.col + 1
    if __is_double_char(start_line_txt, end_pos.col + 1) then
        idx_end = idx_end + 1
    end

    if is_same_line then
        local pre_selection = string.sub(start_line_txt, 1, start_pos.col)
        local the_selection = string.sub(start_line_txt, start_pos.col + 1, idx_end)
        local post_selection = string.sub(start_line_txt, idx_end + 1)

        if is_removing then
            -- remove **
            local sub = string.sub(the_selection, 1 + #before, -1 - #after)
            start_line_txt = pre_selection .. sub .. post_selection

            -- Removed #after and #before because both surrounds are on the same line.
            __update_end_selection_mark(end_pos.line, end_pos.col - #after - #before)
        else
            -- add **
            start_line_txt = pre_selection .. before .. the_selection .. after .. post_selection

            -- Added #after and #before because both surrounds are on the same line.
            __update_end_selection_mark(end_pos.line, end_pos.col + #after + #before)
        end

        __buf_set_line(start_pos.line, { start_line_txt })
    else
        local newline = false
        if opts and opts.newline then
            newline = opts.newline
        end

        local pre_end_line_txt = string.sub(end_line_txt, 1, idx_end)
        local post_end_line_txt = string.sub(end_line_txt, idx_end + 1)

        local pre_start_line_txt = string.sub(start_line_txt, 1, start_pos.col)
        local post_start_line_txt = string.sub(start_line_txt, start_pos.col + 1)

        if is_removing then
            -- remove **
            if newline then
                --- Removing lines
                vim.cmd(start_pos.line .. 'd')
                vim.cmd(end_pos.line - 1 .. 'd')

                __update_end_selection_mark(end_pos.line - 2, #pre_end_line_txt)

                --- Change cursor position
                vim.api.nvim_win_set_cursor(0, { end_pos.line - 2, 1 })
            else
                start_line_txt = pre_start_line_txt .. post_start_line_txt:sub(1 + #before)
                end_line_txt = pre_end_line_txt:sub(1, -1 - #after) .. post_end_line_txt

                -- Removed only #after because surrounds are on different lines.
                __update_end_selection_mark(end_pos.line, end_pos.col - #after)
            end
        else
            -- add **
            if newline then
                vim.api.nvim_buf_set_lines(0, start_pos.line - 1, start_pos.line - 1, false, { before })
                __update_start_selection_mark(start_pos.line, 1)
                vim.api.nvim_buf_set_lines(0, end_pos.line + 1, end_pos.line + 1, false, { after })
                __update_end_selection_mark(end_pos.line + 2, #after)
            else
                start_line_txt = pre_start_line_txt .. before .. post_start_line_txt
                end_line_txt = pre_end_line_txt .. after .. post_end_line_txt

                -- Added only #after because surrounds are on different lines.
                __update_end_selection_mark(end_pos.line, end_pos.col + #after)
            end
        end

        if not newline then
            __buf_set_line(start_pos.line, { start_line_txt })
            __buf_set_line(end_pos.line, { end_line_txt })
        end
    end
end

--- Wrap the selected text with "before" and "after" strings.
---
---@param sur (table) Single line surrounds
---  - before: (string) The string to place before the selected text
---  - after: (string) The string to place after the selected text
---@param mln_sur (table?) Multi line surrounds
---  - before: (string) The string to place before the selected text
---  - after: (string) The string to place after the selected text
---@param opts (nil|table) Optional keyword arguments:
---  - newline: Add surrounds string "before" and "after" to newline
--              In multi-line selection
local function __wrap_sel_text(sur, mln_sur, opts)
    local _start = vim.api.nvim_buf_get_mark(0, '<') -- [line, col]
    local _end = vim.api.nvim_buf_get_mark(0, '>') -- [line, col]

    local start_pos = { line = _start[1], col = _start[2] }
    local end_pos = { line = _end[1], col = _end[2] }

    local before, after = sur[1], sur[2]

    if vim.fn.visualmode() == 'V' then
        -- Manually count chars of last selected line in V-LINE mode due
        -- to '>' reaching max int value. Address if it's neovim bug.
        local end_line = __buf_get_line(end_pos.line)
        end_pos.col = #end_line - 1

        if mln_sur then
            before, after = mln_sur[1], mln_sur[2]
        end
    end

    __toggle_surround(start_pos, end_pos, before, after, opts)
end

--- Surrounds the selected text with '**'
function M.bold()
    __wrap_sel_text({ '**', '**' })
end

--- Surrounds the selected text with '_'
function M.italic()
    __wrap_sel_text({ '_', '_' })
end


--- Prompts the user for a link and surrounds the selected text
--- with that link.
function M.link()
    vim.ui.input({ prompt = 'Href:' }, function(href)
        if href ~= nil then
            __wrap_sel_text({ '[', '](' .. href .. ')' })
        end
    end)
end

--- Surrounds the selected text with '`' and '```' for multi-line
--- selections (V-LINE).
function M.code()
    __wrap_sel_text({ '`', '`' }, { '```', '```' }, { newline = true })
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_autocmd('FileType', {
        desc = 'markdowny.nvim keymaps',
        pattern = opts.filetypes or 'markdown',
        callback = function()
            vim.keymap.set('v', '<C-b>', ":lua require('markdowny').bold()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-i>', ":lua require('markdowny').italic()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-e>', ":lua require('markdowny').code()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-k>', ":lua require('markdowny').link()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-c>', ":lua require('markdowny').inline_code()<cr>", { buffer = 0 })
        end,
    })
end

return M
