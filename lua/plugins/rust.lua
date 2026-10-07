return {
  {
    "LazyVim/LazyVim",
    opts = {
      -- rust-analyzer provides run, debug, implementation, and test CodeLens
      -- actions. LazyVim supplies the display, refresh, and <leader>cc bindings.
      codelens = {
        enabled = true,
      },
    },
  },
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            -- Keep diagnostics useful while editing by running Clippy whenever
            -- a Rust buffer is saved. Formatting remains manual (<leader>cf).
            check = {
              command = "clippy",
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>rr",
        "<cmd>RustLsp runnables<cr>",
        ft = "rust",
        desc = "Rust Runnables",
      },
      {
        "<leader>dr",
        "<cmd>RustLsp debuggables<cr>",
        ft = "rust",
        desc = "Debug Rust Target",
      },
    },
  },
}
