-- bootstrap lazy.nvim, LazyVim and your plugins
if vim.fn.exists(":LspInfo") == 0 then
  vim.api.nvim_create_user_command("LspInfo", function()
    vim.cmd("checkhealth vim.lsp")
  end, { desc = "LSP status (compat alias for checkhealth vim.lsp)" })
end

require("config.lazy")
