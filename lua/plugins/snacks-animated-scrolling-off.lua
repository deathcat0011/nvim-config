return {
	"folke/snacks.nvim",
	opts = function(_, opts)
		opts.scroll = opts.scroll or {}
		opts.scroll.enabled = false -- Disable scrolling animations

		opts.bigfile = opts.bigfile or {}
		opts.bigfile.size = opts.bigfile.size or 8 * 1024 * 1024

		opts.picker = opts.picker or {}
		opts.picker.sources = opts.picker.sources or {}
		opts.picker.sources.projects = vim.tbl_deep_extend("force", opts.picker.sources.projects or {}, {
			confirm = { "tcd", "load_session" },
		})

		opts.dashboard = opts.dashboard or {}
		opts.dashboard.preset = opts.dashboard.preset or {}
		opts.dashboard.preset.keys = opts.dashboard.preset.keys or {}

		local has_projects_key = false
		for _, item in ipairs(opts.dashboard.preset.keys) do
			if item.key == "p" or item.desc == "Projects" then
				has_projects_key = true
				break
			end
		end

		if not has_projects_key then
			table.insert(opts.dashboard.preset.keys, 5, {
				icon = " ",
				key = "p",
				desc = "Projects",
				action = ":lua Snacks.picker.projects()",
			})
		end
	end,
}
