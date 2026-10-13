-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local markdown_display = vim.api.nvim_create_augroup("markdown_display", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = markdown_display,
    pattern = { "markdown", "mdx", "quarto", "rmd" },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
        vim.opt_local.breakindent = true
        vim.opt_local.breakindentopt = ""
        vim.opt_local.showbreak = "  "
        vim.opt_local.spell = true
        vim.opt_local.conceallevel = 2
        vim.opt_local.concealcursor = "nc"

        vim.keymap.set("n", "<leader>cp", "<cmd>RenderMarkdown preview<cr>", {
            buffer = true,
            desc = "Markdown Side Preview",
        })
    end,
})

local function time_diffs_between_h2()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local times = {}

    for lnum, line in ipairs(lines) do
        local hh, mm, reason = line:match("^##%s*(%d%d?):(%d%d)(.*)")
        if hh and mm then
            local hhn, mmn = tonumber(hh), tonumber(mm)
            local total = hhn * 60 + mmn
            table.insert(times, {
                line = lnum,
                minutes = total,
                reason = vim.trim(reason):gsub("|", "\\|"),
            })
        end
    end

    local rows = { { "mins", "lines", "hours", "reason" } }
    for i = 1, #times - 1 do
        local a, b = times[i], times[i + 1]
        local diff = b.minutes - a.minutes
        if diff < 0 then
            diff = diff + 24 * 60
        end

        local h = math.floor(diff / 60)
        local m = diff % 60
        table.insert(
            rows,
            { tostring(diff), string.format("%d:%d", a.line, b.line), string.format("%dh %02dm", h, m), a.reason }
        )
    end

    if #rows == 1 then
        vim.notify("No consecutive ## hh:mm headings found", vim.log.levels.WARN)
        return
    end

    local widths = { 0, 0, 0, 0 }
    for _, row in ipairs(rows) do
        for column, cell in ipairs(row) do
            widths[column] = math.max(widths[column], #cell)
        end
    end

    local out = {}
    for row_index, row in ipairs(rows) do
        local cells = {}
        for column, cell in ipairs(row) do
            cells[column] = cell .. string.rep(" ", widths[column] - #cell)
        end
        table.insert(out, "| " .. table.concat(cells, " | ") .. " |")
        if row_index == 1 then
            local separator = {}
            for column, width in ipairs(widths) do
                separator[column] = string.rep("-", width)
            end
            table.insert(out, "| " .. table.concat(separator, " | ") .. " |")
        end
    end

    local result = table.concat(out, "\n")
    vim.fn.setreg("+", result)
    vim.notify(result)
end

-- optional command

vim.api.nvim_create_user_command("HeadingTimeDiffs", time_diffs_between_h2, {})
