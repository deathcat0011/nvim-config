-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = true
vim.opt.swapfile = false
vim.opt.undofile = true

local nushell = vim.fn.exepath("nu")
if nushell == "" and vim.fn.has("win32") == 1 then
    local local_app_data = vim.env.LOCALAPPDATA
    local installed_nushell = local_app_data and (local_app_data .. "\\Programs\\nu\\bin\\nu.exe") or nil
    if installed_nushell and vim.fn.executable(installed_nushell) == 1 then
        nushell = installed_nushell
    end
end

if nushell ~= "" then
    vim.opt.shell = nushell
    vim.opt.shellcmdflag = "--stdin --no-newline -c"
    vim.opt.shellredir = "out+err> %s"
    vim.opt.shellpipe =
        "| complete | update stderr { ansi strip } | tee { get stderr | save --force --raw %s } | into record"
    vim.opt.shellquote = ""
    vim.opt.shellxescape = ""
    vim.opt.shellxquote = ""
    vim.opt.shelltemp = false
end

local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
    vim.fn.mkdir(undodir, "p")
end
vim.opt.undodir = undodir

if vim.g.neovide then
    vim.opt.guifont = "FiraCode Nerd Font:12,Symbols Nerd Font:12,Segoe UI Symbol:12"

    local neovide_scale_file = vim.fn.stdpath("state") .. "/neovide_scale.txt"
    if vim.fn.filereadable(neovide_scale_file) == 1 then
        local saved_scale = tonumber(vim.fn.readfile(neovide_scale_file)[1])
        if saved_scale and saved_scale > 0 then
            vim.g.neovide_scale_factor = saved_scale
        end
    end

    vim.g.neovide_scale_default = vim.g.neovide_scale_factor or 1.0
end
