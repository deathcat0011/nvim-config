-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>bs", function()
	vim.cmd.enew()
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "hide"
	vim.bo.swapfile = false
end, { desc = "Open Scratch Buffer" })

vim.keymap.set("n", "<leader>aa", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot Chat" })
vim.keymap.set("n", "<leader>cp", "<cmd>Copilot panel<cr>", { desc = "Copilot Panel" })
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit Terminal Mode" })

vim.keymap.set("n", "<leader>/", "gcc", { remap = true, desc = "Comment Line" })
vim.keymap.set("v", "<leader>/", "gc", { remap = true, desc = "Comment Selection" })

vim.keymap.set("n", "gg", "ggzz", { desc = "Go to Top (Center)" })
vim.keymap.set("n", "G", "Gzz", { desc = "Go to Bottom (Center)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half Page Up (Center)" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half Page Down (Center)" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next Search Result (Center)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev Search Result (Center)" })

local function parse_pipe_row(line)
	local indent, body = line:match("^(%s*)(.-)%s*$")
	if body == "" or not body:find("|", 1, true) then
		return nil
	end

	local leading = body:sub(1, 1) == "|"
	local trailing = body:sub(-1) == "|"
	local core = body
	if leading then
		core = core:sub(2)
	end
	if trailing then
		core = core:sub(1, -2)
	end

	local cells = {}
	local start = 1
	while true do
		local idx = core:find("|", start, true)
		if not idx then
			table.insert(cells, vim.trim(core:sub(start)))
			break
		end

		table.insert(cells, vim.trim(core:sub(start, idx - 1)))
		start = idx + 1
	end

	return {
		indent = indent,
		leading = leading,
		trailing = trailing,
		cells = cells,
	}
end

local function parse_formattable_row(line)
	local pipe_row = parse_pipe_row(line)
	if pipe_row then
		pipe_row.is_pipe_row = true
		return pipe_row
	end

	local indent, body = line:match("^(%s*)(.-)%s*$")
	if not body or body == "" then
		return nil
	end

	return {
		indent = indent,
		leading = false,
		trailing = false,
		cells = { vim.trim(body) },
		is_pipe_row = false,
	}
end

local function is_separator_cell(cell)
	return cell:match("^:?-+:?$") ~= nil
end

local function is_separator_row(cells)
	if #cells == 0 then
		return false
	end

	for _, cell in ipairs(cells) do
		if cell == "" or not is_separator_cell(cell) then
			return false
		end
	end

	return true
end

local function pad_right(text, width)
	local current = vim.fn.strdisplaywidth(text)
	if current >= width then
		return text
	end
	return text .. string.rep(" ", width - current)
end

local function format_separator_cell(cell, width)
	local left = cell:sub(1, 1) == ":"
	local right = cell:sub(-1) == ":"
	local target = math.max(3, width)
	local dash_count = target - (left and 1 or 0) - (right and 1 or 0)
	if dash_count < 1 then
		dash_count = 1
	end

	return (left and ":" or "") .. string.rep("-", dash_count) .. (right and ":" or "")
end

local function separator_alignment(cell)
	local left = cell:sub(1, 1) == ":"
	local right = cell:sub(-1) == ":"
	if left and right then
		return "center"
	end
	if left then
		return "left"
	end
	if right then
		return "right"
	end
	return "none" 
end

local function render_row(cells, indent, style)
	local content = table.concat(cells, " | ")
	if style.leading then
		content = "| " .. content
	end
	if style.trailing then
		content = content .. " |"
	end
	return indent .. content
end

local table_format_markdown_filetypes = {
	markdown = true,
	mdx = true,
	quarto = true,
	rmd = true,
}

local function format_pipe_table_lines(lines, opts)
	opts = opts or {}
	local rows = {}
	local style = nil
	local column_count = 0
	local separator_template = nil

	for idx, line in ipairs(lines) do
		local parsed = parse_formattable_row(line)
		if not parsed then
			return nil, ("Line %d is empty or unsupported"):format(idx)
		end

		if parsed.is_pipe_row and not style then
			style = {
				leading = parsed.leading,
				trailing = parsed.trailing,	
			}
		end

		column_count = math.max(column_count, #parsed.cells)
		table.insert(rows, parsed)

		if not separator_template and is_separator_row(parsed.cells) then
			separator_template = vim.deepcopy(parsed.cells)
		end
	end

	style = style or {
		leading = false,
		trailing = false,
	}

	if opts.force_outer_pipes then
		style.leading = true
		style.trailing = true
	end

	if column_count < 2 then
		return nil, "Table needs at least 2 columns"
	end

	local data_rows = {}
	for idx, row in ipairs(rows) do
		if idx == 1 or not is_separator_row(row.cells) then
			table.insert(data_rows, row)
		end
	end

	if #data_rows == 0 then
		return nil, "Table needs at least one non-separator row"
	end

	local widths = {}
	for _, row in ipairs(data_rows) do
		local separator = is_separator_row(row.cells)
		for col = 1, column_count do
			row.cells[col] = row.cells[col] or ""
			if not separator then
				widths[col] = math.max(widths[col] or 0, vim.fn.strdisplaywidth(row.cells[col]))
			end
		end
	end

	for col = 1, column_count do
		widths[col] = math.max(widths[col] or 0, 3)
	end

	local alignments = {}
	for col = 1, column_count do
		local marker = separator_template and separator_template[col] or ""
		if marker == "" then
			marker = "---"
		end
		alignments[col] = separator_alignment(marker)
	end

	local formatted = {}
	local header = data_rows[1]
	local header_cells = {}
	for col = 1, column_count do
		header_cells[col] = pad_right(header.cells[col] or "", widths[col])
	end
	formatted[#formatted + 1] = render_row(header_cells, header.indent, style)

	local separator_cells = {}
	for col = 1, column_count do
		local marker = "---"
		if alignments[col] == "left" then
			marker = ":--"
		elseif alignments[col] == "right" then
			marker = "--:"
		elseif alignments[col] == "center" then
			marker = ":-:"
		end
		separator_cells[col] = format_separator_cell(marker, widths[col])
	end
	formatted[#formatted + 1] = render_row(separator_cells, header.indent, style)

	for idx = 2, #data_rows do
		local row = data_rows[idx]
		local cells = {}
		for col = 1, column_count do
			cells[col] = pad_right(row.cells[col] or "", widths[col])
		end
		formatted[#formatted + 1] = render_row(cells, row.indent, style)
	end

	return formatted
end

local function is_blank_line(line)
	return line:match("^%s*$") ~= nil
end

local function trim_range_to_non_empty(bufnr, start_line, end_line)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count == 0 then
		return nil, nil
	end

	start_line = math.max(1, math.min(start_line, line_count))
	end_line = math.max(1, math.min(end_line, line_count))
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	local left = 1
	local right = #lines

	while left <= right and is_blank_line(lines[left]) do
		left = left + 1
	end

	while right >= left and is_blank_line(lines[right]) do
		right = right - 1
	end

	if left > right then
		return nil, nil
	end

	return start_line + left - 1, start_line + right - 1
end

local function find_table_block(bufnr, current_line)
	local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if not parse_formattable_row(buffer_lines[current_line] or "") then
		return nil, nil
	end

	local start_line = current_line
	while start_line > 1 and parse_formattable_row(buffer_lines[start_line - 1]) do
		start_line = start_line - 1
	end

	local end_line = current_line
	while end_line < #buffer_lines and parse_formattable_row(buffer_lines[end_line + 1]) do
		end_line = end_line + 1
	end

	return start_line, end_line
end

local function format_pipe_table_range(bufnr, start_line, end_line)
	start_line, end_line = trim_range_to_non_empty(bufnr, start_line, end_line)
	if not start_line then
		vim.notify("Table formatting skipped: selection is empty after trimming", vim.log.levels.WARN)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	if #lines == 0 then
		return
	end

	local force_outer_pipes = table_format_markdown_filetypes[vim.bo[bufnr].filetype] == true
	local formatted, err = format_pipe_table_lines(lines, {
		force_outer_pipes = force_outer_pipes,
	})
	if not formatted then
		vim.notify("Table formatting skipped: " .. err, vim.log.levels.WARN)
		return
	end

	if vim.deep_equal(lines, formatted) then
		return
	end

	vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, formatted)
end

local function format_pipe_table_command(cmd)
	local bufnr = vim.api.nvim_get_current_buf()
	local start_line, end_line

	if cmd.range == 0 then
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
		start_line, end_line = find_table_block(bufnr, cursor_line)
		if not start_line then
			vim.notify("Cursor is not on a pipe-delimited table row", vim.log.levels.WARN)
			return
		end
	else
		start_line, end_line = cmd.line1, cmd.line2
	end

	format_pipe_table_range(bufnr, start_line, end_line)
end

local function format_pipe_table_visual_selection()
	local bufnr = vim.api.nvim_get_current_buf()
	local mode = vim.api.nvim_get_mode().mode
	local start_line
	local end_line

	if mode == "v" or mode == "V" or mode == "\22" then
		start_line = vim.fn.line("v")
		end_line = vim.fn.line(".")
	else
		start_line = vim.fn.getpos("'<")[2]
		end_line = vim.fn.getpos("'>")[2]
	end

	if start_line == 0 or end_line == 0 then
		start_line = vim.fn.line("'<")
		end_line = vim.fn.line("'>")
	end

	if start_line == 0 or end_line == 0 then
		vim.notify("Table formatting skipped: no visual selection found", vim.log.levels.WARN)
		return
	end

	format_pipe_table_range(bufnr, start_line, end_line)
end

vim.api.nvim_create_user_command("TableFormat", format_pipe_table_command, {
	desc = "Format a pipe-delimited table in-place",
	range = true,
})

vim.keymap.set("n", "<leader>Tf", "<cmd>TableFormat<cr>", { desc = "Table: Format Block" })
vim.keymap.set("v", "<leader>Tf", format_pipe_table_visual_selection, { desc = "Table: Format Selection" })
vim.keymap.set("n", "<leader>tf", "<cmd>TableFormat<cr>", { desc = "Table: Format (Alias)" })
vim.keymap.set("v", "<leader>tf", format_pipe_table_visual_selection, { desc = "Table: Format Selection (Alias)" })

local function indent_line()
	vim.cmd.normal({ args = { ">>" }, bang = true })
end

local function unindent_line()
	vim.cmd.normal({ args = { "<<" }, bang = true })
end

vim.keymap.set("i", "<C-Tab>", function()
	indent_line()
end, { desc = "Indent Line" })

for _, lhs in ipairs({ "<C-S-Tab>", "<C-ISO_Left_Tab>", "<C-kB>" }) do
	vim.keymap.set("i", lhs, function()
		unindent_line()
	end, { desc = "Unindent Line" })
end

if vim.g.neovide then
	local neovide_scale_file = vim.fn.stdpath("state") .. "/neovide_scale.txt"
	local function persist_scale()
		vim.fn.writefile({ tostring(vim.g.neovide_scale_factor or 1.0) }, neovide_scale_file)
	end

	local function change_scale(delta)
		vim.g.neovide_scale_factor = math.max(0.5, (vim.g.neovide_scale_factor or 1.0) + delta)
		persist_scale()
	end

	vim.keymap.set({ "n", "v" }, "<C-=>", function()
		change_scale(0.05)
	end, { desc = "Increase Font Size" })

	vim.keymap.set({ "n", "v" }, "<C-->", function()
		change_scale(-0.05)
	end, { desc = "Decrease Font Size" })

	vim.keymap.set({ "n", "v" }, "<C-0>", function()
		vim.g.neovide_scale_factor = vim.g.neovide_scale_default or 1.0
		persist_scale()
	end, { desc = "Reset Font Size" })

	vim.keymap.set({ "n", "v" }, "<leader>us", function()
		vim.g.neovide_scale_default = vim.g.neovide_scale_factor or 1.0
		persist_scale()
		vim.notify(string.format("Saved Neovide scale: %.2f", vim.g.neovide_scale_default), vim.log.levels.INFO)
	end, { desc = "Save Font Size" })

	vim.keymap.set({ "n", "v" }, "<F11>", function()
		vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
	end, { desc = "Toggle Fullscreen" })
end
