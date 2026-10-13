return {
  {
    "nwiizo/codex.nvim",
    event = "VeryLazy",
    cmd = {
      "Codex",
      "CodexOpen",
      "CodexClose",
      "CodexFocus",
      "CodexResume",
      "CodexContinue",
      "CodexReview",
      "CodexAsk",
      "CodexSendVisual",
      "CodexAdd",
      "CodexHealth",
    },
    keys = {
      {
        "<leader>ax",
        "<cmd>CodexFocus<cr>",
        desc = "Codex: Focus or Hide",
      },
      {
        "<leader>ar",
        "<cmd>CodexResume<cr>",
        desc = "Codex: Resume Session",
      },
      {
        "<leader>as",
        ":<C-U>CodexSendVisual<cr>",
        mode = "v",
        desc = "Codex: Send Selection",
      },
    },
    opts = {
      backend = "terminal",
      cwd = "root",
      focus_after_send = false,
      terminal = {
        layout = "split",
        split_side = "right",
        split_width_percentage = 0.35,
      },
      -- Copilot Chat owns <leader>aa. Keep Codex selection actions nearby
      -- without overriding that mapping.
      selection = {
        keymaps = {
          ask = "<leader>oa",
          edit = "<leader>oe",
        },
      },
    },
  },
}
