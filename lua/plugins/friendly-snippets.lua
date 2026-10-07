return {
  {
    "rafamadriz/friendly-snippets",
    config = function()
      local path = vim.fn.stdpath("data") .. "/lazy/friendly-snippets/snippets/PowerShell.json"
      if vim.fn.filereadable(path) == 0 then
        return
      end

      local lines = vim.fn.readfile(path)
      local changed = false

      for i, line in ipairs(lines) do
        -- Neovim's snippet parser expects escaped literal '$' before tabstops.
        local patched = (" " .. line):gsub("([^\\])%$%${", "%1\\$${"):sub(2)
        if patched ~= line then
          lines[i] = patched
          changed = true
        end
      end

      if changed then
        vim.fn.writefile(lines, path)
      end
    end,
  },
}
