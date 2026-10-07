return {
  {
    "debugloop/telescope-undo.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      {
        "<leader>su",
        function()
          local telescope = require("telescope")
          pcall(telescope.load_extension, "undo")
          telescope.extensions.undo.undo()
        end,
        desc = "Undo History",
      },
    },
  },
}
