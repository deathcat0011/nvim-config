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

local function groovy_root(bufnr, on_dir)
  local root = vim.fs.root(bufnr, { ".git", "Jenkinsfile", "src", "vars" })
  on_dir(root or vim.fn.getcwd())
end

local function groovy_classpath()
  return vim.fn.glob(
    vim.fs.joinpath(vim.fn.stdpath("data"), "groovy", "lib", "*.jar"),
    true,
    true
  )
end

vim.filetype.add({
  filename = {
    Jenkinsfile = "groovy",
  },
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        groovyls = {
          cmd = groovyls_cmd(),
          filetypes = { "groovy" },
          root_dir = groovy_root,
          settings = {
            groovy = {
              -- Source files under src/ are discovered from the workspace.
              classpath = groovy_classpath(),
            },
          },
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
