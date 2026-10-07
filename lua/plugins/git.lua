return {
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "Git Status (Fugitive)" },
    },
  },
  {
    "rbong/vim-flog",
    dependencies = { "tpope/vim-fugitive" },
    cmd = { "Flog", "Flogsplit", "Floggit" },
    keys = {
      { "<leader>gl", "<cmd>Flogsplit<cr>", desc = "Git Graph (Flog)" },
      { "<leader>gL", "<cmd>Flogsplit -all -max-count=200<cr>", desc = "Git Graph (All Branches)" },
    },
  },
}