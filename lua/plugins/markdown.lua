local markdown_filetypes = {
    markdown = true,
    mdx = true,
    quarto = true,
    rmd = true,
}

local markdown_extensions = {
    md = true,
    markdown = true,
}

local default_code_fence_aliases = {
    python = "py",
    ps1 = "powershell",
    psm1 = "powershell",
    psd1 = "powershell",
    dosbatch = "bat",
}

local include_preview_defaults = {
    marker_style = "callout",
    max_depth = 8,
    split_command = "vnew",
    reuse_existing_preview = true,
    code_fence_aliases = default_code_fence_aliases,
}

local blocked_include_extensions = {
    png = true,
    jpg = true,
    jpeg = true,
    gif = true,
    webp = true,
    svg = true,
    ico = true,
    bmp = true,
    mp3 = true,
    wav = true,
    ogg = true,
    flac = true,
    mp4 = true,
    mov = true,
    avi = true,
    mkv = true,
    pdf = true,
    zip = true,
    gz = true,
    bz2 = true,
    xz = true,
    rar = true,
    ["7z"] = true,
    tar = true,
    exe = true,
    dll = true,
    so = true,
    dylib = true,
    class = true,
    jar = true,
    o = true,
    obj = true,
    bin = true,
}

local function is_absolute_path(path)
    return path:match("^%a:[/\\]") ~= nil or path:match("^/") ~= nil or path:match("^\\\\") ~= nil
end

local function get_include_preview_opts()
    local user = vim.g.markdown_include_preview
    if type(user) ~= "table" then
        return vim.deepcopy(include_preview_defaults)
    end

    local merged = vim.tbl_deep_extend("force", vim.deepcopy(include_preview_defaults), user)
    merged.code_fence_aliases = merged.code_fence_aliases or {}
    return merged
end

local function get_path_extension(path)
    local ext = vim.fn.fnamemodify(path, ":e")
    return ext and ext:lower() or ""
end

local function normalize_include_target(target, source_dir, opts)
    if not target or target == "" then
        return nil
    end

    local cleaned = vim.trim(target)
    if cleaned:sub(1, 1) == "<" and cleaned:sub(-1) == ">" then
        cleaned = cleaned:sub(2, -2)
    end

    cleaned = cleaned:gsub("#.*$", "")
    cleaned = vim.trim(cleaned)
    if cleaned == "" then
        return nil
    end

    if cleaned:match("^%a[%w+.-]*://") or cleaned:match("^data:") then
        return nil
    end

    local resolved

    if is_absolute_path(cleaned) then
        resolved = vim.fs.normalize(cleaned)
    else
        resolved = vim.fs.normalize(vim.fs.joinpath(source_dir, cleaned))
    end

    local ext = get_path_extension(resolved)
    if ext == "" then
        return nil
    end

    if blocked_include_extensions[ext] then
        return nil
    end

    if markdown_extensions[ext] then
        return {
            path = resolved,
            kind = "markdown",
        }
    end

    if ext == "txt" then
        return {
            path = resolved,
            kind = "text",
            language = "text",
        }
    end

    local detected = vim.filetype.match({ filename = resolved }) or ext
    local language = opts.code_fence_aliases[detected] or detected
    return {
        path = resolved,
        kind = "code",
        language = language,
    }
end

local function parse_obsidian_embed(line, source_dir, opts)
    local ref = line:match("^%s*!%[%[([^%]]+)%]%]%s*$")
    if not ref then
        return nil
    end

    local target = vim.trim((ref:match("^([^|]+)") or ref))
    target = target:gsub("#.*$", "")
    if target == "" then
        return nil
    end

    local basename = vim.fn.fnamemodify(target, ":t")
    if basename ~= "" and basename:match("%.[^.]+$") == nil then
        target = target .. ".md"
    end

    return normalize_include_target(target, source_dir, opts)
end

local function parse_markdown_embed(line, source_dir, opts)
    local link = line:match("^%s*!%[[^%]]*%]%((.-)%)%s*$")
    if not link then
        return nil
    end

    local target = vim.trim(link)
    target = target:match("^([^%s]+)") or target
    return normalize_include_target(target, source_dir, opts)
end

local function quote_block(lines)
    local out = {}
    for _, l in ipairs(lines) do
        if l == "" then
            table.insert(out, ">")
        else
            table.insert(out, "> " .. l)
        end
    end
    return out
end

local function format_include_label(path)
    local label = vim.fn.fnamemodify(path, ":.")
    if label == path then
        label = vim.fn.fnamemodify(path, ":~")
    end
    return label
end

local function quote_fenced_block(lines, language)
    local out = { "> ```" .. language }
    for _, l in ipairs(lines) do
        if l == "" then
            table.insert(out, ">")
        else
            table.insert(out, "> " .. l)
        end
    end
    table.insert(out, "> ```")
    return out
end

local function include_heading_line(include, from_label, opts)
    local suffix = ""
    if include.kind ~= "markdown" and include.language and include.language ~= "" then
        suffix = " (" .. include.language .. ")"
    end

    if opts.marker_style == "label" then
        return "> **Included from:** " .. from_label .. suffix
    end

    return "> [!include] Included from " .. from_label .. suffix
end

local function split_text_lines(text)
    local normalized = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = vim.split(normalized, "\n", { plain = true })
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines, #lines)
    end
    return lines
end

local function try_iconv_to_utf8(text, from_encoding)
    local ok, converted = pcall(vim.fn.iconv, text, from_encoding, "utf-8")
    if ok and type(converted) == "string" then
        return converted
    end
    return nil
end

local function codepoint_to_utf8(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    end

    if codepoint <= 0x7FF then
        local b1 = 0xC0 + math.floor(codepoint / 0x40)
        local b2 = 0x80 + (codepoint % 0x40)
        return string.char(b1, b2)
    end

    if codepoint <= 0xFFFF then
        local b1 = 0xE0 + math.floor(codepoint / 0x1000)
        local b2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
        local b3 = 0x80 + (codepoint % 0x40)
        return string.char(b1, b2, b3)
    end

    if codepoint <= 0x10FFFF then
        local b1 = 0xF0 + math.floor(codepoint / 0x40000)
        local b2 = 0x80 + (math.floor(codepoint / 0x1000) % 0x40)
        local b3 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
        local b4 = 0x80 + (codepoint % 0x40)
        return string.char(b1, b2, b3, b4)
    end

    return "\239\191\189"
end

local function decode_utf16_bytes(blob, little_endian)
    local out = {}
    local i = 1
    local n = #blob

    while i + 1 <= n do
        local b1, b2 = blob:byte(i, i + 1)
        local unit
        if little_endian then
            unit = b1 + b2 * 256
        else
            unit = b2 + b1 * 256
        end

        if unit == 0 then
            i = i + 2
        elseif unit >= 0xD800 and unit <= 0xDBFF and i + 3 <= n then
            local c1, c2 = blob:byte(i + 2, i + 3)
            local next_unit
            if little_endian then
                next_unit = c1 + c2 * 256
            else
                next_unit = c2 + c1 * 256
            end

            if next_unit >= 0xDC00 and next_unit <= 0xDFFF then
                local codepoint = 0x10000 + (unit - 0xD800) * 0x400 + (next_unit - 0xDC00)
                out[#out + 1] = codepoint_to_utf8(codepoint)
                i = i + 4
            else
                out[#out + 1] = codepoint_to_utf8(0xFFFD)
                i = i + 2
            end
        else
            out[#out + 1] = codepoint_to_utf8(unit)
            i = i + 2
        end
    end

    return table.concat(out)
end

local function guess_utf16_endianness(blob)
    local odd_null = 0
    local even_null = 0
    for i = 1, #blob do
        if blob:byte(i) == 0 then
            if i % 2 == 0 then
                even_null = even_null + 1
            else
                odd_null = odd_null + 1
            end
        end
    end

    if even_null > odd_null then
        return true
    end
    if odd_null > even_null then
        return false
    end
    return nil
end

local function decode_text_blob(blob)
    if blob == "" then
        return ""
    end

    local b1, b2, b3 = blob:byte(1, 3)
    if b1 == 0xEF and b2 == 0xBB and b3 == 0xBF then
        return blob:sub(4)
    end

    if b1 == 0xFF and b2 == 0xFE then
        local body = blob:sub(3)
        return try_iconv_to_utf8(body, "utf-16le") or decode_utf16_bytes(body, true)
    end

    if b1 == 0xFE and b2 == 0xFF then
        local body = blob:sub(3)
        return try_iconv_to_utf8(body, "utf-16be") or decode_utf16_bytes(body, false)
    end

    local null_count = select(2, blob:gsub("\0", ""))
    if null_count > 0 then
        local decoded = try_iconv_to_utf8(blob, "utf-16le") or try_iconv_to_utf8(blob, "utf-16be")
        if decoded then
            return decoded
        end

        local endian = guess_utf16_endianness(blob)
        if endian ~= nil then
            return decode_utf16_bytes(blob, endian)
        end
        return blob:gsub("\0", "")
    end

    return blob
end

local function safe_read_file_lines(path)
    local ok_open, file = pcall(io.open, path, "rb")
    if ok_open and file then
        local ok_read, blob = pcall(function()
            return file:read("*a")
        end)
        file:close()

        if ok_read and type(blob) == "string" then
            local decoded = decode_text_blob(blob)
            return split_text_lines(decoded)
        end
    end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return nil
    end

    local out = {}
    for _, line in ipairs(lines) do
        local text = tostring(line or "")
        text = text:gsub("\0", ""):gsub("\r", "")
        table.insert(out, text)
    end
    return out
end

local function expand_markdown_file(file_path, depth, stack, opts)
    if depth > opts.max_depth then
        return { "[include skipped: max include depth reached]" }
    end

    if stack[file_path] then
        return { "[include skipped: recursive include detected]" }
    end

    if vim.fn.filereadable(file_path) == 0 then
        return { "[include skipped: file not found]" }
    end

    stack[file_path] = true
    local source_dir = vim.fn.fnamemodify(file_path, ":h")
    local lines = safe_read_file_lines(file_path)
    if not lines then
        stack[file_path] = nil
        return { "[include skipped: could not read file]" }
    end
    local out = {}

    for _, line in ipairs(lines) do
        local include = parse_obsidian_embed(line, source_dir, opts) or parse_markdown_embed(line, source_dir, opts)
        if include then
            if vim.fn.filereadable(include.path) == 1 then
                local from_label = format_include_label(include.path)
                table.insert(out, include_heading_line(include, from_label, opts))
                table.insert(out, ">")

                if include.kind == "markdown" then
                    local nested = expand_markdown_file(include.path, depth + 1, stack, opts)
                    vim.list_extend(out, quote_block(nested))
                else
                    local included_lines = safe_read_file_lines(include.path)
                    if not included_lines then
                        table.insert(out, "> [include skipped: could not read file]")
                    else
                        vim.list_extend(out, quote_fenced_block(included_lines, include.language or "text"))
                    end
                end

                table.insert(out, ">")
            else
                table.insert(out, "> [!include] Missing file: " .. include.path)
            end
        else
            table.insert(out, line)
        end
    end

    stack[file_path] = nil
    return out
end

local function get_preview_source(bufnr)
    local ok, source = pcall(vim.api.nvim_buf_get_var, bufnr, "include_preview_source")
    if not ok or type(source) ~= "string" or source == "" then
        return nil
    end
    return vim.fs.normalize(source)
end

local function find_preview_buffer_for_source(source_path)
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            local source = get_preview_source(bufnr)
            if source == source_path then
                return bufnr
            end
        end
    end
    return nil
end

local function sanitize_buffer_lines(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
        local text = tostring(line or "")
        text = text:gsub("\0", "")
        text = text:gsub("\r\n", "\n"):gsub("\r", "")
        if text:find("\n", 1, true) then
            for _, part in ipairs(vim.split(text, "\n", { plain = true })) do
                table.insert(out, part)
            end
        else
            table.insert(out, text)
        end
    end
    return out
end

local function render_into_preview_buffer(preview_buf, source_path, expanded)
    vim.bo[preview_buf].buftype = "nofile"
    vim.bo[preview_buf].bufhidden = "wipe"
    vim.bo[preview_buf].swapfile = false
    vim.bo[preview_buf].modifiable = true
    vim.bo[preview_buf].readonly = false

    local safe_expanded = sanitize_buffer_lines(expanded)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, safe_expanded)

    local preview_name = "[Include Preview] " .. vim.fn.fnamemodify(source_path, ":t")
    pcall(vim.api.nvim_buf_set_name, preview_buf, preview_name)

    vim.bo[preview_buf].filetype = "markdown"
    vim.bo[preview_buf].readonly = true
    vim.bo[preview_buf].modifiable = false

    pcall(vim.api.nvim_buf_set_var, preview_buf, "include_preview_source", source_path)
    vim.keymap.set("n", "<leader>mR", "<cmd>MarkdownIncludePreviewRefresh<cr>", {
        buffer = preview_buf,
        desc = "Refresh Markdown Include Preview",
    })
end

local function ensure_preview_window(preview_buf, split_command)
    local winid = vim.fn.bufwinid(preview_buf)
    if winid ~= -1 then
        vim.api.nvim_set_current_win(winid)
        return
    end

    vim.cmd(split_command)
    vim.api.nvim_win_set_buf(0, preview_buf)
end

local function open_markdown_include_preview()
    local opts = get_include_preview_opts()
    local src_buf = vim.api.nvim_get_current_buf()
    local ft = vim.bo[src_buf].filetype
    if not markdown_filetypes[ft] then
        vim.notify("Include preview is only available for markdown buffers", vim.log.levels.WARN)
        return
    end

    local source_path = vim.api.nvim_buf_get_name(src_buf)
    if source_path == "" then
        vim.notify("Save this note first so includes can be resolved from disk", vim.log.levels.WARN)
        return
    end

    source_path = vim.fs.normalize(source_path)
    local expanded = expand_markdown_file(source_path, 0, {}, opts)

    local preview_buf
    if opts.reuse_existing_preview then
        preview_buf = find_preview_buffer_for_source(source_path)
    end

    if preview_buf then
        render_into_preview_buffer(preview_buf, source_path, expanded)
        ensure_preview_window(preview_buf, opts.split_command)
        return
    end

    vim.cmd(opts.split_command)
    preview_buf = vim.api.nvim_get_current_buf()
    render_into_preview_buffer(preview_buf, source_path, expanded)
end

local function refresh_markdown_include_preview()
    local opts = get_include_preview_opts()
    local current_buf = vim.api.nvim_get_current_buf()
    local source_path = get_preview_source(current_buf)
    local preview_buf = current_buf

    if not source_path then
        local ft = vim.bo[current_buf].filetype
        if not markdown_filetypes[ft] then
            vim.notify("Include preview refresh is only available for markdown buffers", vim.log.levels.WARN)
            return
        end

        source_path = vim.api.nvim_buf_get_name(current_buf)
        if source_path == "" then
            vim.notify("Save this note first so includes can be resolved from disk", vim.log.levels.WARN)
            return
        end

        source_path = vim.fs.normalize(source_path)
        preview_buf = find_preview_buffer_for_source(source_path)
        if not preview_buf then
            open_markdown_include_preview()
            return
        end
    end

    if vim.fn.filereadable(source_path) == 0 then
        vim.notify("Include preview source file is not readable: " .. source_path, vim.log.levels.ERROR)
        return
    end

    local expanded = expand_markdown_file(source_path, 0, {}, opts)
    render_into_preview_buffer(preview_buf, source_path, expanded)
    ensure_preview_window(preview_buf, opts.split_command)
end

return {
    {
        "mfussenegger/nvim-lint",
        opts = function(_, opts)
            opts.linters = opts.linters or {}
            opts.linters["markdownlint-cli2"] = vim.tbl_deep_extend("force", opts.linters["markdownlint-cli2"] or {}, {
                args = {
                    "--config",
                    vim.fn.stdpath("config") .. "/.markdownlint.jsonc",
                    "-",
                },
            })
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            for _, parser in ipairs({ "markdown", "markdown_inline", "html", "yaml" }) do
                if not vim.tbl_contains(opts.ensure_installed, parser) then
                    table.insert(opts.ensure_installed, parser)
                end
            end
        end,
    },

    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "mdx", "quarto", "rmd" },
        init = function()
            vim.api.nvim_create_user_command("MarkdownIncludePreview", open_markdown_include_preview, {
                desc = "Open visual markdown include preview",
            })
            vim.api.nvim_create_user_command("MarkdownIncludePreviewRefresh", refresh_markdown_include_preview, {
                desc = "Refresh visual markdown include preview",
            })
        end,
        config = function(_, opts)
            require("render-markdown").setup(opts)
        end,
        opts = function(_, opts)
            opts = opts or {}

            opts.preset = "lazy"
            opts.file_types = { "markdown", "mdx", "quarto", "rmd" }
            opts.render_modes = { "n", "c", "t" }

            opts.anti_conceal = vim.tbl_deep_extend("force", opts.anti_conceal or {}, {
                above = 0,
                below = 0,
            })

            opts.heading = vim.tbl_deep_extend("force", opts.heading or {}, {
                position = "inline",
                sign = true,
                enabled = true,
                icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
                atx = true,
            })

            opts.code = vim.tbl_deep_extend("force", opts.code or {}, {
                sign = false,
                width = "full",
                border = "thin",
            })

            opts.callout = vim.tbl_deep_extend("force", opts.callout or {}, {
                include = {
                    raw = "[!INCLUDE]",
                    rendered = "Included",
                    highlight = "RenderMarkdownInfo",
                    quote_icon = "▏",
                    category = "custom",
                },
                note = {
                    raw = "[!NOTE]",
                    rendered = "󰋽 Note",
                    highlight = "RenderMarkdownInfo",
                    category = "github",
                },
                tip = {
                    raw = "[!TIP]",
                    rendered = "󰌶 Tip",
                    highlight = "RenderMarkdownSuccess",
                    category = "github",
                },
                important = {
                    raw = "[!IMPORTANT]",
                    rendered = "󰅾 Important",
                    highlight = "RenderMarkdownHint",
                    category = "github",
                },
                warning = {
                    raw = "[!WARNING]",
                    rendered = "󰀪 Warning",
                    highlight = "RenderMarkdownWarn",
                    category = "github",
                },
                caution = {
                    raw = "[!CAUTION]",
                    rendered = "󰳦 Caution",
                    highlight = "RenderMarkdownError",
                    category = "github",
                },
                -- Obsidian: https://help.obsidian.md/Editing+and+formatting/Callouts
                abstract = {
                    raw = "[!ABSTRACT]",
                    rendered = "󰨸 Abstract",
                    highlight = "RenderMarkdownInfo",
                    category = "obsidian",
                },
                summary = {
                    raw = "[!SUMMARY]",
                    rendered = "󰨸 Summary",
                    highlight = "RenderMarkdownInfo",
                    category = "obsidian",
                },
                tldr = {
                    raw = "[!TLDR]",
                    rendered = "󰨸 Tldr",
                    highlight = "RenderMarkdownInfo",
                    category = "obsidian",
                },
                info = {
                    raw = "[!INFO]",
                    rendered = "󰋽 Info",
                    highlight = "RenderMarkdownInfo",
                    category = "obsidian",
                },
                todo = {
                    raw = "[!TODO]",
                    rendered = "󰗡 Todo",
                    highlight = "RenderMarkdownInfo",
                    category = "obsidian",
                },
                hint = {
                    raw = "[!HINT]",
                    rendered = "󰌶 Hint",
                    highlight = "RenderMarkdownSuccess",
                    category = "obsidian",
                },
                success = {
                    raw = "[!SUCCESS]",
                    rendered = "󰄬 Success",
                    highlight = "RenderMarkdownSuccess",
                    category = "obsidian",
                },
                check = {
                    raw = "[!CHECK]",
                    rendered = "󰄬 Check",
                    highlight = "RenderMarkdownSuccess",
                    category = "obsidian",
                },
                done = {
                    raw = "[!DONE]",
                    rendered = "󰄬 Done",
                    highlight = "RenderMarkdownSuccess",
                    category = "obsidian",
                },
                question = {
                    raw = "[!QUESTION]",
                    rendered = "󰘥 Question",
                    highlight = "RenderMarkdownWarn",
                    category = "obsidian",
                },
                help = {
                    raw = "[!HELP]",
                    rendered = "󰘥 Help",
                    highlight = "RenderMarkdownWarn",
                    category = "obsidian",
                },
                faq = {
                    raw = "[!FAQ]",
                    rendered = "󰘥 Faq",
                    highlight = "RenderMarkdownWarn",
                    category = "obsidian",
                },
                attention = {
                    raw = "[!ATTENTION]",
                    rendered = "󰀪 Attention",
                    highlight = "RenderMarkdownWarn",
                    category = "obsidian",
                },
                failure = {
                    raw = "[!FAILURE]",
                    rendered = "󰅖 Failure",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                fail = {
                    raw = "[!FAIL]",
                    rendered = "󰅖 Fail",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                missing = {
                    raw = "[!MISSING]",
                    rendered = "󰅖 Missing",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                danger = {
                    raw = "[!DANGER]",
                    rendered = "󱐌 Danger",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                error = {
                    raw = "[!ERROR]",
                    rendered = "󱐌 Error",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                bug = {
                    raw = "[!BUG]",
                    rendered = "󰨰 Bug",
                    highlight = "RenderMarkdownError",
                    category = "obsidian",
                },
                example = {
                    raw = "[!EXAMPLE]",
                    rendered = "󰉹 Example",
                    highlight = "RenderMarkdownHint",
                    category = "obsidian",
                },
                quote = {
                    raw = "[!QUOTE]",
                    rendered = "󱆨 Quote",
                    highlight = "RenderMarkdownQuote",
                    category = "obsidian",
                },
                cite = {
                    raw = "[!CITE]",
                    rendered = "󱆨 Cite",
                    highlight = "RenderMarkdownQuote",
                    category = "obsidian",
                },
            })

            opts.overrides = vim.tbl_deep_extend("force", opts.overrides or {}, {
                buftype = {
                    nofile = {
                        quote = {
                            icon = "▏",
                            highlight = "RenderMarkdownInfo",
                        },
                    },
                },
            })

            opts.pipe_table = vim.tbl_deep_extend("force", opts.pipe_table or {}, {
                preset = "round",
                cell = "overlay",
                border_enabled = true,
            })

            opts.win_options = vim.tbl_deep_extend("force", opts.win_options or {}, {
                conceallevel = { rendered = 3 },
                concealcursor = { rendered = "" },
            })

            opts.link = {
                -- Turn on / off inline link icon rendering.
                enabled = true,
                -- Additional modes to render links.
                render_modes = false,
                -- How to handle footnote links, start with a '^'.
                footnote = {
                    -- Turn on / off footnote rendering.
                    enabled = true,
                    -- Inlined with content.
                    icon = "󰯔 ",
                    -- Custom processing for footnote body to show.
                    -- Runs before prefix / suffix are added and superscript processing.
                    body = function(ctx)
                        return ctx.text
                    end,
                    -- Replace value with superscript equivalent.
                    superscript = true,
                    -- Added before link content.
                    prefix = "",
                    -- Added after link content.
                    suffix = "",
                },
                -- Inlined with 'image' elements.
                image = "󰥶 ",
                -- Check custom for 'image' elements.
                image_custom = true,
                -- Inlined with 'email_autolink' elements.
                email = "󰀓 ",
                -- Fallback icon for 'inline_link' and 'uri_autolink' elements.
                hyperlink = "󰌹 ",
                -- Applies to the inlined icon as a fallback.
                highlight = "RenderMarkdownLink",
                -- Applies to the link title.
                highlight_title = "RenderMarkdownLinkTitle",
                -- Applies to WikiLink elements.
                wiki = {
                    -- Turn on / off WikiLink rendering.
                    enabled = true,
                    -- Inlined with content.
                    icon = "󱗖 ",
                    -- Hide destination if there is an alias.
                    conceal_destination = true,
                    -- Custom processing for WikiLink body to show.
                    body = function()
                        return nil
                    end,
                    -- Applies to the inlined icon.
                    highlight = "RenderMarkdownWikiLink",
                    -- Highlight for item associated with the WikiLink.
                    scope_highlight = nil,
                },
            -- Define custom destination patterns so icons can quickly inform you of what a link
        -- contains. Applies to 'image', 'inline_link', 'uri_autolink', and WikiLink nodes.
        -- When multiple patterns match a link the one with the longer pattern is used.
        -- The key is for healthcheck and to allow users to change its values, value type below.
        -- | icon      | gets inlined before the link text                               |
        -- | pattern   | matched against the destination text                            |
        -- | kind      | optional determines how pattern is checked                      |
        -- |           | pattern | @see :h lua-patterns, is the default if not set       |
        -- |           | suffix  | @see :h vim.endswith()                                |
        -- |           | url     | similar to pattern with additional prefix checks      |
        -- | priority  | optional used when multiple match, uses pattern length if empty |
        -- | highlight | optional highlight for 'icon', uses fallback highlight if empty |
        -- stylua: ignore
        custom = {
            web = { icon = '󰖟 ', pattern = '^http' },
            apple = { icon = ' ', pattern = 'apple%.com', kind = 'url' },
            discord = { icon = '󰙯 ', pattern = 'discord%.com', kind = 'url' },
            github = { icon = '󰊤 ', pattern = 'github%.com', kind = 'url' },
            gitlab = { icon = '󰮠 ', pattern = 'gitlab%.com', kind = 'url' },
            google = { icon = '󰊭 ', pattern = 'google%.com', kind = 'url' },
            hackernews = { icon = ' ', pattern = 'ycombinator%.com', kind = 'url' },
            linkedin = { icon = '󰌻 ', pattern = 'linkedin%.com', kind = 'url' },
            microsoft = { icon = ' ', pattern = 'microsoft%.com', kind = 'url' },
            neovim = { icon = ' ', pattern = 'neovim%.io', kind = 'url' },
            reddit = { icon = '󰑍 ', pattern = 'reddit%.com', kind = 'url' },
            slack = { icon = '󰒱 ', pattern = 'slack%.com', kind = 'url' },
            stackoverflow = { icon = '󰓌 ', pattern = 'stackoverflow%.com', kind = 'url' },
            steam = { icon = ' ', pattern = 'steampowered%.com', kind = 'url' },
            twitter = { icon = ' ', pattern = 'twitter%.com', kind = 'url' },
            wikipedia = { icon = '󰖬 ', pattern = 'wikipedia%.org', kind = 'url' },
            x = { icon = ' ', pattern = 'x%.com', kind = 'url' },
            youtube = { icon = '󰗃 ', pattern = 'youtube[^.]*%.com', kind = 'url' },
            youtube_short = { icon = '󰗃 ', pattern = 'youtu%.be', kind = 'url' },
        },
            }
            opts.indent = {
                -- Mimic org-indent-mode behavior by indenting everything under a heading based on the
                -- level of the heading. Indenting starts from level 2 headings onward by default.

                -- Turn on / off org-indent-mode.
                enabled = true,
                -- Additional modes to render indents.
                render_modes = false,
                -- Amount of additional padding added for each heading level.
                per_level = 2,
                -- Heading levels <= this value will not be indented.
                -- Use 0 to begin indenting from the very first level.
                skip_level = 1,
                -- Do not indent heading titles, only the body.
                skip_heading = false,
                -- Prefix added when indenting, one per level.
                icon = "▎",
                -- Priority to assign to extmarks.
                priority = 0,
                -- Applied to icon.
                highlight = "RenderMarkdownIndent",
            }
            opts.html = {
                -- Turn on / off all HTML rendering.
                enabled = true,
                -- Additional modes to render HTML.
                render_modes = false,
                comment = {
                    -- Useful context to have when evaluating values.
                    -- | text | text value of the comment node |

                    -- Turn on / off HTML comment concealing.
                    conceal = true,
                    -- Text to inline before the concealed comment.
                    -- Output is evaluated depending on the type.
                    -- | function | `value(context)` |
                    -- | string   | `value`          |
                    -- | nil      | nothing          |
                    text = nil,
                    -- Highlight for the inlined text.
                    highlight = "RenderMarkdownHtmlComment",
                },
                -- HTML tags whose start and end will be hidden and icon shown.
                -- The key is matched against the tag name, value type below.
                -- | icon            | optional icon inlined at start of tag           |
                -- | highlight       | optional highlight for the icon                 |
                -- | scope_highlight | optional highlight for item associated with tag |
                tag = {},
            }
            opts.code = {
                -- Turn on / off code block & inline code rendering.
                enabled = true,
                -- Additional modes to render code blocks.
                render_modes = false,
                -- Turn on / off sign column related rendering.
                sign = true,
                -- Whether to conceal nodes at the top and bottom of code blocks.
                conceal_delimiters = true,
                -- Turn on / off language heading related rendering.
                language = true,
                -- Determines where language icon is rendered.
                -- | center | center of code block |
                -- | right  | right of code block  |
                -- | left   | left of code block   |
                position = "left",
                -- Whether to include the language icon above code blocks.
                language_icon = true,
                -- Whether to include the language name above code blocks.
                language_name = true,
                -- Whether to include the language info above code blocks.
                language_info = true,
                -- Amount of padding to add around the language.
                -- If a float < 1 is provided it is treated as a percentage of available window space.
                language_pad = 0,
                -- A list of language names for which rendering will be disabled.
                disable = {},
                -- A list of language names for which background highlighting will be disabled.
                -- Likely because that language has background highlights itself.
                -- Use a boolean to make behavior apply to all languages.
                -- Borders above & below blocks will continue to be rendered.
                disable_background = { "diff" },
                -- Number of lines from start/end to skip rendering background.
                background_inset = 1,
                -- Width of the code block background.
                -- | block | width of the code block  |
                -- | full  | full width of the window |
                width = "full",
                -- Amount of margin to add to the left of code blocks.
                -- If a float < 1 is provided it is treated as a percentage of available window space.
                -- Margin available space is computed after accounting for padding.
                left_margin = 0,
                -- Amount of padding to add to the left of code blocks.
                -- If a float < 1 is provided it is treated as a percentage of available window space.
                left_pad = 0,
                -- Amount of padding to add to the right of code blocks when width is 'block'.
                -- If a float < 1 is provided it is treated as a percentage of available window space.
                right_pad = 0,
                -- Minimum width to use for code blocks when width is 'block'.
                min_width = 0,
                -- Determines how the top / bottom of code block are rendered.
                -- | none  | do not render a border                               |
                -- | thick | use the same highlight as the code body              |
                -- | thin  | when lines are empty overlay the above & below icons |
                -- | hide  | conceal lines unless language name or icon is added  |
                border = "hide",
                -- Used above code blocks to fill remaining space around language.
                language_border = "█",
                -- Added to the left of language.
                language_left = "",
                -- Added to the right of language.
                language_right = "",
                -- Used above code blocks for thin border.
                above = "▄",
                -- Used below code blocks for thin border.
                below = "▀",
                -- Turn on / off inline code related rendering.
                inline = true,
                -- Icon to add to the left of inline code.
                inline_left = "",
                -- Icon to add to the right of inline code.
                inline_right = "",
                -- Padding to add to the left & right of inline code.
                inline_pad = 0,
                -- Priority to assign to code background highlight.
                priority = 140,
                -- Highlight for code blocks.
                highlight = "RenderMarkdownCode",
                -- Highlight for code info section, after the language.
                highlight_info = "RenderMarkdownCodeInfo",
                -- Highlight for language, overrides icon provider value.
                highlight_language = nil,
                -- Highlight for border, use false to add no highlight.
                highlight_border = "RenderMarkdownCodeBorder",
                -- Highlight for language, used if icon provider does not have a value.
                highlight_fallback = "RenderMarkdownCodeFallback",
                -- Highlight for inline code.
                highlight_inline = "RenderMarkdownCodeInline",
                -- Highlight for inline code left icon, default to reverse of highlight_inline.
                highlight_inline_left = nil,
                -- Highlight for inline code right icon, default to reverse of highlight_inline.
                highlight_inline_right = nil,
                -- Determines how code blocks & inline code are rendered.
                -- | none     | { enabled = false }                           |
                -- | normal   | { language = false }                          |
                -- | language | { disable_background = true, inline = false } |
                -- | full     | uses all default values                       |
                style = "full",
            }

            opts.quote = {
                -- Turn on / off block quote & callout rendering.
                enabled = true,
                -- Additional modes to render quotes.
                render_modes = false,
                -- Replaces '>' of 'block_quote'.
                icon = "▋",
                -- Whether to repeat icon on wrapped lines. Requires neovim >= 0.10. This will obscure text
                -- if incorrectly configured with :h 'showbreak', :h 'breakindent' and :h 'breakindentopt'.
                -- A combination of these that is likely to work follows.
                -- | showbreak      | '  ' (2 spaces)   |
                -- | breakindent    | true              |
                -- | breakindentopt | '' (empty string) |
                -- These are not validated by this plugin. If you want to avoid adding these to your main
                -- configuration then set them in win_options for this plugin.
                repeat_linebreak = false,
                -- Highlight for the quote icon.
                -- If a list is provided output is evaluated by `cycle(value, level)`.
                highlight = {
                    "RenderMarkdownQuote1",
                    "RenderMarkdownQuote2",
                    "RenderMarkdownQuote3",
                    "RenderMarkdownQuote4",
                    "RenderMarkdownQuote5",
                    "RenderMarkdownQuote6",
                },
            }

            return opts
        end,
        keys = {
            { "<leader>ur", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle Markdown Render" },
            { "<leader>uR", "<cmd>RenderMarkdown buf_toggle<cr>", desc = "Toggle Markdown Render (Buffer)" },
            { "<leader>mp", "<cmd>RenderMarkdown preview<cr>", desc = "Markdown Side Preview" },
            { "<leader>mI", open_markdown_include_preview, desc = "Markdown Include Preview" },
            { "<leader>mR", refresh_markdown_include_preview, desc = "Refresh Markdown Include Preview" },
        },
    },
}
