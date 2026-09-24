-- repro/repro.lua serves as a reproducible environment for your plugin.
-- When a user wants to open a new ISSUE, they are asked to reproduce their
-- issue in a clean minimal environment.
-- The repro directory is a safe place to mess around with various config
-- without affecting your main setup.
--
-- 1. Clone customrss.nvim and cd into customrss.nvim
-- 2. Run `nvim -u repro/repro.lua`
-- 3. Run :checkhealth customrss
-- 4. Reproduce the issue
-- 5. Report the repro.lua and logs from .repro directory in the issue

vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

local plugins = {
	{
		"flushwhy/customrss.nvim",
		dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"),
		lazy = false,
		opts = {
			feeds = {
				{ url = "https://neovim.io/news.xml", name = "Neovim" },
				{ url = "https://github.blog/feed/", name = "GitHub Blog" },
			},
			sort = { by = "date" },
		},
	},

	-- other plugins ...
}

require("lazy.minit").repro({ spec = plugins })

-- Add additional setup here ...

-- Since this plugin has no display of its own, print a quick summary to
-- prove the pipeline works end-to-end in this repro environment.
vim.api.nvim_create_autocmd("User", {
	pattern = "CustomRssUpdated",
	callback = function(args)
		local entries, errors = args.data.entries, args.data.errors
		print(("[repro] customrss.nvim: %d entries, %d errors"):format(#entries, #errors))
		for _, e in ipairs(entries) do
			print(("  - [%s] %s"):format(e.feed_name, e.title))
		end
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		vim.defer_fn(function()
			require("customrss").refresh()
		end, 200)
	end,
})

-- RESOURCES:
--   - https://lazy.folke.io/developers#reprolua
