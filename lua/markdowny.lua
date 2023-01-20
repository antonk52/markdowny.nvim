local M = {}

-- cyrillic characters are double width
local function is_double_char(str, idx)
    local char = str:sub(idx, idx + 1)
    local display_width = vim.fn.strdisplaywidth(char)

    return #char ~= display_width
end

--- This update the '>' mark, which represents the end column
--- position of the selection, in visual mode after adding or
--- removing a surround, enabling the region to be reselected
--- using the 'gv' command.
---
--- @param line number The line number of the mark to update.
--- @param col  number The column/row number of the mark to update.
local function update_end_selection_mark(line, col)
    vim.api.nvim_buf_set_mark(0, '>', line, col, {})
end

local function surrounder(pos_start, pos_end, before, after)
    local start_line = vim.api.nvim_buf_get_lines(0, pos_start[1] - 1, pos_start[1], true)[1]

    local is_same_line = pos_start[1] == pos_end[1]

    if is_same_line then
        local first = start_line:sub(pos_start[2] + 1, pos_start[2] + #before) == before
        local last = start_line:sub(pos_end[2] + 2 - #after, pos_end[2] + 1) == after
        local is_removing = first and last

        local idx_end = pos_end[2] + 1
        if is_double_char(start_line, pos_end[2] + 1) then
            idx_end = idx_end + 1
        end

        local pre_selection = string.sub(start_line, 1, pos_start[2])
        local the_selection = string.sub(start_line, pos_start[2] + 1, idx_end)
        local post_selection = string.sub(start_line, idx_end + 1)

        if is_removing then
            local sub = string.sub(the_selection, 1 + #before, -1 - #after)
            start_line = pre_selection .. sub .. post_selection
        else
            start_line = pre_selection .. before .. the_selection .. after .. post_selection
        end

        vim.api.nvim_buf_set_lines(0, pos_start[1] - 1, pos_start[1], true, { start_line })

        -- Added #after and #before because both surrounds are on the same line.
        update_end_selection_mark(pos_end[1], pos_end[2] + #after + #before)
    else
        local end_line = vim.api.nvim_buf_get_lines(0, pos_end[1] - 1, pos_end[1], true)[1]

        local first = start_line:sub(pos_start[2] + 1, pos_start[2] + #before) == before
        local last = end_line:sub(pos_end[2] + 2 - #after, pos_end[2] + 1) == after
        local is_removing = first and last

        local idx_end = pos_end[2] + 1

        if is_double_char(end_line, pos_end[2]) then
            idx_end = idx_end + 1
        end

        local pre_end_line = string.sub(end_line, 1, idx_end)
        local post_end_line = string.sub(end_line, idx_end + 1)

        local pre_start_line = string.sub(start_line, 1, pos_start[2])
        local post_start_line = string.sub(start_line, pos_start[2] + 1)

        if is_removing then
            -- remove **
            start_line = pre_start_line .. post_start_line:sub(1 + #before)
            end_line = pre_end_line:sub(1, -1 - #after) .. post_end_line
        else
            -- add **
            start_line = pre_start_line .. before .. post_start_line
            end_line = pre_end_line .. after .. post_end_line
        end

        vim.api.nvim_buf_set_lines(0, pos_start[1] - 1, pos_start[1], true, { start_line })
        vim.api.nvim_buf_set_lines(0, pos_end[1] - 1, pos_end[1], true, { end_line })

        -- Added only #after because surrounds are on different lines.
        update_end_selection_mark(pos_end[1], pos_end[2] + #after)
    end
end
local function make_surrounder_function(before, after)
    return function()
        -- {line, col}
        local pos_start = vim.api.nvim_buf_get_mark(0, '<')
        -- {line, col}
        local pos_end = vim.api.nvim_buf_get_mark(0, '>')

        -- Manually count chars of last selected line in V-LINE mode due
        -- to '>' reaching max int value. Address if it's neovim bug.
        if vim.fn.visualmode() == 'V' then
            local last_line = vim.api.nvim_buf_get_lines(0, pos_end[1] - 1, pos_end[1], true)[1]
            pos_end[2] = #last_line - 1
        end

        surrounder(pos_start, pos_end, before, after)
    end
end

M.bold = make_surrounder_function('**', '**')
M.italic = make_surrounder_function('_', '_')

function M.link()
    local pos_start = vim.api.nvim_buf_get_mark(0, '<')
    local pos_end = vim.api.nvim_buf_get_mark(0, '>')

    vim.ui.input({ prompt = 'Href:' }, function(href)
        if href == nil then
            return
        end
        surrounder(pos_start, pos_end, '[', '](' .. href .. ')')
    end)
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_create_autocmd('FileType', {
        desc = 'markdowny.nvim keymaps',
        pattern = opts.filetypes or 'markdown',
        callback = function()
            vim.keymap.set('v', '<C-b>', ":lua require('markdowny').bold()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-i>', ":lua require('markdowny').italic()<cr>", { buffer = 0 })
            vim.keymap.set('v', '<C-k>', ":lua require('markdowny').link()<cr>", { buffer = 0 })
        end,
    })
end

return M
