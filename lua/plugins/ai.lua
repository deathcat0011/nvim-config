return {
  {
    "ravitemer/mcphub.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    build = "npm install -g mcp-hub@latest",
    enabled = function()
      local function has_servers(path)
        if vim.fn.filereadable(path) ~= 1 then
          return false
        end

        local lines = vim.fn.readfile(path)
        if not lines or #lines == 0 then
          return false
        end

        local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
        if not ok or type(decoded) ~= "table" then
          return false
        end

        local servers = decoded.mcpServers or decoded.servers
        if type(servers) ~= "table" then
          return false
        end

        return next(servers) ~= nil
      end

      local candidates = {
        vim.fn.expand("~/.config/mcphub/servers.json"),
        vim.fn.getcwd() .. "/.mcphub/servers.json",
        vim.fn.getcwd() .. "/.vscode/mcp.json",
        vim.fn.getcwd() .. "/.cursor/mcp.json",
      }

      for _, path in ipairs(candidates) do
        if has_servers(path) then
          return true
        end
      end

      return false
    end,
    opts = {},
  },
  {
    "zbirenbaum/copilot.lua",
    commit = "1f4a565e55e7f265ff22c527ce79d54956b6647a",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      copilot_node_command = "node",
      -- Reuse an existing cached server binary on Windows to avoid flaky plugin-local extraction paths.
      server = {
        type = "binary",
        custom_server_filepath = (function()
          local matches = vim.fn.glob(vim.fn.stdpath("data") .. "/copilot.lua/lsp/*/win32-x64/*/copilot-language-server.exe", true, true)
          if type(matches) == "table" and #matches > 0 then
            table.sort(matches)
            return matches[#matches]
          end
          return nil
        end)(),
      },
      suggestion = {
        enabled = true,
        auto_trigger = false,
        keymap = {
          accept = "<M-l>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = true },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "zbirenbaum/copilot.lua",
      "nvim-lua/plenary.nvim",
    },
    cmd = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatToggle",
      "CopilotChatClose",
      "CopilotChatReset",
      "CopilotChatModels",
    },
    opts = {
      model = "gpt-5.3-codex",
      temperature = 0.1,
      auto_insert_mode = true,
      trusted_tools = { "file", "glob", "grep" },
      window = {
        layout = "float",
        width = 0.5,
        border = "rounded",
        -- zindex = 100,
      },
    },
  },
}
  