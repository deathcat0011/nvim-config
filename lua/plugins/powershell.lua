local function resolve_powershell_shell()
  local candidates = {
    vim.fn.exepath("pwsh"),
    vim.fn.exepath("pwsh.exe"),
    vim.fn.exepath("powershell.exe"),
    vim.fn.exepath("powershell"),
  }

  for _, path in ipairs(candidates) do
    if path and path ~= "" then
      return path
    end
  end

  return "powershell.exe"
end

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "powershell-editor-services") then
        table.insert(opts.ensure_installed, "powershell-editor-services")
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        powershell_es = {
          shell = resolve_powershell_shell(),
          bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
          filetypes = { "ps1", "psm1", "psd1" },
        },
      },
    },
  },
}