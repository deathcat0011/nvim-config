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
