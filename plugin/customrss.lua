-- In this file you define the User commands, i.e. how the user will interact
-- with your plugin. The require() is inside each callback — the main module
-- is only loaded when the user actually invokes the command (lazy-loading).

local sub_cmds = {
	refresh = function()
		require("customrss").refresh(function(entries, errors)
			local Util = require("customrss.util")
			if #errors == 0 then
				Util.info(("customrss.nvim: refreshed, %d entr%s"):format(#entries, #entries == 1 and "y" or "ies"))
			end
		end)
	end,
	mark_all_read = function()
		require("customrss").mark_all_read()
	end,
}

local sub_cmds_keys = {}
for k, _ in pairs(sub_cmds) do
	table.insert(sub_cmds_keys, k)
end

local function main_cmd(opts)
	local sub_cmd = sub_cmds[opts.args]
	if sub_cmd == nil then
		vim.notify("CustomRss: invalid subcommand", vim.log.levels.ERROR, { title = "customrss.nvim" })
	else
		sub_cmd()
	end
end

vim.api.nvim_create_user_command("CustomRss", main_cmd, {
	nargs = "?",
	desc = "customrss.nvim commands",
	complete = function(arg_lead, _, _)
		return vim.iter(sub_cmds_keys)
			:filter(function(sub_cmd)
				return sub_cmd:find(arg_lead) ~= nil
			end)
			:totable()
	end,
})

-- RESOURCES:
--  - :help nvim_create_user_command()
--  - https://github.com/lumen-oss/nvim-best-practices?tab=readme-ov-file#speaking_head-user-commands
