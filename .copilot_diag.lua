local candidates = {}
local function add(path)
  if path and path ~= "" then
    table.insert(candidates, path)
  end
end
add(vim.env.XDG_CONFIG_HOME and (vim.env.XDG_CONFIG_HOME .. "/github-copilot/apps.json"))
add(vim.env.XDG_CONFIG_HOME and (vim.env.XDG_CONFIG_HOME .. "/github-copilot/hosts.json"))
if vim.fn.has("win32") ~= 0 then
  add(vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/github-copilot/apps.json"))
  add(vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/github-copilot/hosts.json"))
  add(vim.env.APPDATA and (vim.env.APPDATA .. "/github-copilot/apps.json"))
  add(vim.env.APPDATA and (vim.env.APPDATA .. "/github-copilot/hosts.json"))
end
add(vim.fn.expand("~/.config/github-copilot/apps.json"))
add(vim.fn.expand("~/.config/github-copilot/hosts.json"))
add(vim.fn.expand("~/github-copilot/apps.json"))
add(vim.fn.expand("~/github-copilot/hosts.json"))
print('CANDIDATES')
for _,p in ipairs(candidates) do
  print(p .. ' => ' .. tostring(vim.fn.filereadable(p)))
end
local p=require('lazy.core.config').plugins['copilot.lua']
print('PLUGIN_EXISTS', p ~= nil)
if p then
  print('ENABLED_TYPE', type(p.enabled))
  if type(p.enabled)=='function' then
    local ok,res = pcall(p.enabled)
    print('ENABLED_CALL_OK', ok)
    print('ENABLED_RESULT', res)
  else
    print('ENABLED_VALUE', p.enabled)
  end
end
