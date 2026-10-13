local colorscheme_file = vim.fn.stdpath("state") .. "/colorscheme"
local ok, lines = pcall(vim.fn.readfile, colorscheme_file)
local colorscheme =  "catppuccin-frappe"

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    local selected = vim.g.colors_name
    if selected and selected ~= "" then
      vim.fn.writefile({ selected }, colorscheme_file)
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if colorscheme and colorscheme ~= "" and vim.g.colors_name ~= colorscheme then
      vim.schedule(function()
        vim.cmd.colorscheme(colorscheme)
      end)
    end
  end,
})

return {
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      if colorscheme and colorscheme ~= "" then
        opts.colorscheme = colorscheme
      end
    end,
  },
}
