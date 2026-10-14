local M = {}

---@param path string
---@return string
function M.absolute(path)
    return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function canonical(path)
    local normalized = M.absolute(path)
    return vim.fs.normalize(vim.uv.fs_realpath(normalized) or normalized)
end

local function directory(path)
    if type(path) ~= "string" or path == "" then
        return nil, "cwd provider must return a non-empty directory path"
    end
    local resolved = canonical(path)
    local stat = vim.uv.fs_stat(resolved)
    if not stat or stat.type ~= "directory" then
        return nil, "cwd is not a directory: " .. resolved
    end
    return resolved
end

---@param bufnr? integer
---@param policy string|fun(ctx: CodexNvimCwdContext): string?
---@param markers string[]
---@return string? path
---@return string? error
function M.resolve(bufnr, policy, markers)
    bufnr = bufnr or 0
    local name = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or ""
    local file = name ~= "" and canonical(name) or nil
    local file_dir = file and vim.fs.dirname(file) or nil
    local nvim_cwd = canonical(vim.uv.cwd())

    if type(policy) == "function" then
        local ok, result = pcall(policy, {
            bufnr = bufnr,
            file = file,
            file_dir = file_dir,
            nvim_cwd = nvim_cwd,
        })
        if not ok then
            return nil, "cwd provider failed: " .. tostring(result)
        end
        return directory(result)
    end

    if policy == "root" then
        local root = vim.fs.root(file or nvim_cwd, markers)
        return directory(root or file_dir or nvim_cwd)
    elseif policy == "file" then
        return directory(file_dir or nvim_cwd)
    elseif policy == "nvim" then
        return directory(nvim_cwd)
    end
    return directory(policy)
end

---@param path string
---@param cwd string
---@return string
function M.relative(path, cwd)
    local normalized = canonical(path)
    local normalized_cwd = canonical(cwd):gsub("/+$", "")
    if normalized:gsub("/+$", ""):lower() == normalized_cwd:lower() then
        return "."
    end
    local prefix = normalized_cwd .. "/"
    if normalized:sub(1, #prefix):lower() == prefix:lower() then
        return normalized:sub(#prefix + 1)
    end
    return normalized
end

return M
