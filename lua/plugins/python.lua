local function debug_current_buffer(with_args)
  local filetype = vim.bo.filetype

  if filetype == "rust" then
    if vim.fn.exists(":RustLsp") == 2 then
      vim.cmd("RustLsp debuggables")
    else
      vim.notify("Rust debugging is still loading; try again in a moment", vim.log.levels.WARN)
    end
    return
  end

  local configurations = require("dap").configurations[filetype] or {}
  local preferred_name = with_args and "Debug current file (with args)" or "Debug current file"

  for _, configuration in ipairs(configurations) do
    if configuration.name == preferred_name then
      require("dap").run(configuration)
      return
    end
  end

  if not with_args and #configurations == 1 then
    require("dap").run(configurations[1])
    return
  end

  vim.notify(("No debug configuration for %s"):format(filetype == "" and "this buffer" or filetype), vim.log.levels.WARN)
end

return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "ruff",
        "debugpy",
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        python = { "ruff" },
      },
    },
  },
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "lewis6991/async.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      refactor = {
        inline_func = {
          code_generation = {
            assignment = {
              python = function(opts)
                if #opts.left == 0 then
                  return ""
                end

                if #opts.left < #opts.right then
                  for _ = #opts.left + 1, #opts.right do
                    table.remove(opts.right)
                  end
                elseif #opts.right < #opts.left then
                  for _ = #opts.right + 1, #opts.left do
                    table.insert(opts.right, "None")
                  end
                end

                local left = table.concat(opts.left, ", ")
                local right = table.concat(opts.right, ", ")
                return ("%s = %s"):format(left, right)
              end,
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>cR",
        function()
          require("refactoring").select_refactor()
        end,
        mode = "n",
        desc = "Refactor Menu",
      },
      {
        "<leader>cR",
        function()
          local ref = require("refactoring")
          vim.ui.select({
            { label = "Extract variable", op = "extract_var" },
            { label = "Extract function", op = "extract_func" },
          }, {
            prompt = "Select a visual refactor:",
            format_item = function(item)
              return item.label
            end,
          }, function(choice)
            if not choice then
              return
            end

            local keys = choice.op == "extract_var" and ref.extract_var() or ref.extract_func()
            vim.cmd.normal({ "gv" .. keys, bang = true })
          end)
        end,
        mode = "x",
        desc = "Refactor Menu (Selection)",
      },
      {
        "<leader>cev",
        ":Refactor extract_var<CR>",
        mode = "x",
        desc = "Extract Variable",
      },
      {
        "<leader>cef",
        ":Refactor extract_func<CR>",
        mode = "x",
        desc = "Extract Function",
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      {
        "<leader>du",
        function()
          require("dapui").toggle({})
        end,
        desc = "Toggle Debug UI",
      },
      {
        "<leader>dw",
        function()
          local expr = vim.fn.input("Watch expression: ")
          if expr ~= "" then
            require("dapui.elements.watches").add(expr)
          end
        end,
        desc = "Add Watch",
      },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "v" },
        desc = "Eval Expression",
      },
      {
        "<leader>dh",
        function()
          require("dap.ui.widgets").hover()
        end,
        desc = "Debug Hover",
      },
      {
        "<leader>ds",
        function()
          local widgets = require("dap.ui.widgets")
          widgets.centered_float(widgets.scopes)
        end,
        desc = "Debug Scopes Float",
      },
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dc",
        function()
          local dap = require("dap")
          if dap.session() then
            dap.continue()
          else
            debug_current_buffer()
          end
        end,
        desc = "Debug Continue / Run Current Buffer",
      },
      {
        "<leader>dp",
        function()
          require("dap").pause()
        end,
        desc = "Debug Pause",
      },
      {
        "<leader>dn",
        function()
          require("dap").step_over()
        end,
        desc = "Debug Step Over",
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = "Debug Single Step",
      },
      {
        "<F11>",
        function()
          require("dap").step_into()
        end,
        desc = "Debug Step Into",
      },
      {
        "<S-F11>",
        function()
          require("dap").step_out()
        end,
        desc = "Debug Step Out",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Debug Step Into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_out()
        end,
        desc = "Debug Step Out",
      },
      {
        "<leader>dx",
        function()
          require("dap").terminate()
        end,
        desc = "Debug Stop",
      },
      {
        "<leader>df",
        function()
          debug_current_buffer()
        end,
        desc = "Debug Current Buffer",
      },
      {
        "<leader>dF",
        function()
          debug_current_buffer(true)
        end,
        desc = "Debug Current Buffer (Args)",
      },
      {
        "<leader>dP",
        function()
          for _, cfg in ipairs(require("dap").configurations.python or {}) do
            if cfg.name == "Debug Python module" then
              require("dap").run(cfg)
              return
            end
          end
          vim.notify("Python debug configuration not found: Debug Python module", vim.log.levels.ERROR)
        end,
        desc = "Debug Python Module",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Decorate debugger states in the sign column and current line.
      vim.api.nvim_set_hl(0, "DapBreakpointText", { fg = "#ff6b6b", bold = true })
      vim.api.nvim_set_hl(0, "DapBreakpointLine", { bg = "#3b1f1f" })
      vim.api.nvim_set_hl(0, "DapStoppedText", { fg = "#98c379", bold = true })
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#1f3b2c" })
      vim.api.nvim_set_hl(0, "DapLogPointText", { fg = "#61afef", bold = true })
      vim.api.nvim_set_hl(0, "DapBreakpointRejectedText", { fg = "#7f848e", bold = true })

      vim.fn.sign_define("DapBreakpoint", {
        text = "B",
        texthl = "DapBreakpointText",
        linehl = "DapBreakpointLine",
        numhl = "DapBreakpointText",
      })
      vim.fn.sign_define("DapBreakpointCondition", {
        text = "C",
        texthl = "DapBreakpointText",
        linehl = "DapBreakpointLine",
        numhl = "DapBreakpointText",
      })
      vim.fn.sign_define("DapLogPoint", {
        text = "L",
        texthl = "DapLogPointText",
        numhl = "DapLogPointText",
      })
      vim.fn.sign_define("DapStopped", {
        text = ">",
        texthl = "DapStoppedText",
        linehl = "DapStoppedLine",
        numhl = "DapStoppedText",
      })
      vim.fn.sign_define("DapBreakpointRejected", {
        text = "R",
        texthl = "DapBreakpointRejectedText",
        numhl = "DapBreakpointRejectedText",
      })

      dapui.setup()

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      local function resolve_python_path()
        if vim.env.VIRTUAL_ENV then
          local suffix = vim.fn.has("win32") == 1 and "/Scripts/python.exe" or "/bin/python"
          return vim.env.VIRTUAL_ENV .. suffix
        end

        local cwd = vim.fn.getcwd()
        local candidates = {
          cwd .. "/.venv/Scripts/python.exe",
          cwd .. "/venv/Scripts/python.exe",
          cwd .. "/.venv/bin/python",
          cwd .. "/venv/bin/python",
        }

        for _, path in ipairs(candidates) do
          if vim.fn.executable(path) == 1 then
            return path
          end
        end

        return "python"
      end

      local debugpy_python = "python"
      local ok_registry, registry = pcall(require, "mason-registry")
      if ok_registry and registry.has_package("debugpy") then
        local debugpy = registry.get_package("debugpy")
        local debugpy_path = debugpy:get_install_path()
        local suffix = vim.fn.has("win32") == 1 and "/venv/Scripts/python.exe" or "/venv/bin/python"
        debugpy_python = debugpy_path .. suffix
      end

      require("dap-python").setup(debugpy_python)

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Debug current file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          pythonPath = resolve_python_path,
          justMyCode = true,
        },
        {
          type = "python",
          request = "launch",
          name = "Debug current file (with args)",
          program = "${file}",
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          pythonPath = resolve_python_path,
          args = function()
            local raw = vim.fn.input("Arguments: ")
            if raw == "" then
              return {}
            end
            return vim.split(raw, "%s+", { trimempty = true })
          end,
          justMyCode = true,
        },
        {
          type = "python",
          request = "launch",
          name = "Debug Python module",
          module = function()
            return vim.fn.input("Python module: ")
          end,
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          pythonPath = resolve_python_path,
          justMyCode = true,
        },
      }
    end,
  },
}
