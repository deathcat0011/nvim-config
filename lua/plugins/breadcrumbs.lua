return {
  {
    "SmiteshP/nvim-navic",
    opts = {
      separator = " > ",
      highlight = true,
      depth_limit = 5,
      lazy_update_context = true,
    },
    config = function(_, opts)
      local navic = require("nvim-navic")
      navic.setup(opts)

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.server_capabilities.documentSymbolProvider then
            navic.attach(client, args.buf)
          end
        end,
      })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      local function breadcrumb_component()
        local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":~:.")
        if file == "" then
          file = "[No Name]"
        end

        local ok, navic = pcall(require, "nvim-navic")
        if ok and navic.is_available() then
          local location = navic.get_location()
          if location ~= "" then
            return file .. " > " .. location
          end
        end

        return file
      end

      opts.sections = opts.sections or {}
      opts.sections.lualine_c = opts.sections.lualine_c or {}

      if #opts.sections.lualine_c >= 4 then
        opts.sections.lualine_c[4] = { breadcrumb_component }
      else
        table.insert(opts.sections.lualine_c, { breadcrumb_component })
      end
    end,
  },
}
