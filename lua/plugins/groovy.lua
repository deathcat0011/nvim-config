local function groovyls_cmd()
  local java = "java"
  local jdk21 = vim.fn.glob("C:/Program Files/Microsoft/jdk-21*/bin/java.exe", true, true)
  if type(jdk21) == "table" and #jdk21 > 0 then
    table.sort(jdk21)
    java = jdk21[#jdk21]
  end

  return {
    java,
    "-jar",
    vim.fn.stdpath("data") .. "/mason/packages/groovy-language-server/build/libs/groovy-language-server-all.jar",
  }
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        groovyls = {
          cmd = groovyls_cmd(),
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        groovy = { "npm-groovy-lint" },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "groovy-language-server",
        "npm-groovy-lint",
      },
    },
  },
}