return {
    "necrom4/calcium.nvim",
    cmd = { "Calcium" },
    opts = {
        -- default configuration
        notifications = true, -- notify result
        default_mode = "append", -- or `replace` the expression
        scratchpad = {
            border = "rounded", -- floating window border style (:help 'winborder')
            virtual_text = {
                format = "= %s", -- virtual text format
                highlight_group = "Comment", -- virtual text highlight group
            },
            result_variable = "ans", -- name of the variable for the last computation result
        },
    },
    keys = {
        -- example keymap
        {
            "<leader>c",
            ":Calcium<CR>",
            desc = "Calculate",
            mode = { "n", "v" },
            silent = true,
        },
    },
}
