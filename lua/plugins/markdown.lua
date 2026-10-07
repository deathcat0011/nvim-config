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

local function safe_read_file_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
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

local function render_into_preview_buffer(preview_buf, source_path, expanded)
  vim.bo[preview_buf].buftype = "nofile"
  vim.bo[preview_buf].bufhidden = "wipe"
  vim.bo[preview_buf].swapfile = false
  vim.bo[preview_buf].modifiable = true
  vim.bo[preview_buf].readonly = false

  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, expanded)

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
