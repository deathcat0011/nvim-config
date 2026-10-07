return {
  {
    "akinsho/bufferline.nvim",
    enabled = true,
    opts = {
      options = {
        name_formatter = function(buf)
          local buftype = vim.bo[buf.bufnr].buftype
          if buftype == "terminal" then
            return "[Terminal]"
          elseif buftype == "quickfix" then
            return "[Quickfix]"
          elseif buftype ~= "" or buf.path == "" then
            return "[Scratch]"
          end
          return buf.name
        end,
      },
    },
  },
}
