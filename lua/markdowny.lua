local M = {}

local function surrounder(pos_start, pos_end, before, after)
    local start_line = vim.api.nvim_buf_get_lines(0, pos_start[1] - 1, pos_start[1], true)[1]

    local is_same_line = pos_start[1] == pos_end[1]
    if is_same_line then
        local pre_selection = string.sub(start_line, 1, pos_start[2])
        local the_selection = string.sub(start_line, pos_start[2] + 1, pos_end[2] + 1)
        local post_selection = string.sub(start_line, pos_end[2] + 2)

        local surrounder_len = #before + #after

        local is_removing = vim.startswith(the_selection, before)
            and vim.endswith(the_selection, after)
            and #the_selection > surrounder_len
        if is_removing then
            local sub = string.sub(the_selection, 1 + #before, -1 - #after)
            start_line = pre_selection .. sub .. post_selection
        else
            start_line = pre_selection .. before .. the_selection .. after .. post_selection
        end

        vim.api.nvim_buf_set_lines(0, pos_start[1] - 1, pos_start[1], true, { start_line })
    else
        local end_line = vim.api.nvim_buf_get_lines(0, pos_end[1] - 1, pos_end[1], true)[1]
        local pre_end_line = string.sub(end_line, 1, pos_end[2] + 1)
        local post_end_line = string.sub(end_line, pos_end[2] + 2)

        local pre_start_line = string.sub(start_line, 1, pos_start[2])
        local post_start_line = string.sub(start_line, pos_start[2] + 1)

        vim.pretty_print({ pre_start_line, post_start_line })
        vim.pretty_print({ pre_end_line, post_end_line })

        local first = vim.startswith(post_start_line, before)
        local last = vim.endswith(pre_end_line, after)
        local is_removing = first and last

        if is_removing then
            -- remove **
            start_line = pre_start_line .. string.sub(post_start_line, 1 + #before)
            end_line = string.sub(pre_end_line, 1, -1 - #after) .. post_end_line
        else
            -- add **
            start_line = pre_start_line .. before .. post_start_line
            end_line = pre_end_line .. after .. post_end_line
        end

        vim.api.nvim_buf_set_lines(0, pos_start[1] - 1, pos_start[1], true, { start_line })
        vim.api.nvim_buf_set_lines(0, pos_end[1] - 1, pos_end[1], true, { end_line })
    end
end
local function make_surrounder_function(before, after)
    return function()
        -- {line, col}
        local pos_start = vim.api.nvim_buf_get_mark(0, '<')
        -- {line, col}
        local pos_end = vim.api.nvim_buf_get_mark(0, '>')

        surrounder(pos_start, pos_end, before, after)
    end
end

M.bold = make_surrounder_function('**', '**')
M.italic = make_surrounder_function('_', '_')

function M.link()
    local pos_start = vim.api.nvim_buf_get_mark(0, '<')
    local pos_end = vim.api.nvim_buf_get_mark(0, '>')

    vim.ui.input({ prompt = 'Href:' }, function(href)
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
