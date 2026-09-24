---@diagnostic disable: lowercase-global

local _MODREV, _SPECREV = "scm", "-1"
rockspec_format = "3.0"
version = _MODREV .. _SPECREV

local user = "flushwhy"
package = "customrss.nvim"

description = {
	summary = "CustomRSS feed reader that gets given a list of RSS feeds, and returns sorted lists",
	detailed = [[ This is a RSS feed reader/aggregator that tries to be flat and easy to use. You send a list of RSS feeds, and it returns the feeds in one of the sorted feeds.
  ]],
	labels = { "neovim", "RSS", "plugin", "lua" },
	homepage = "https://github.com/" .. user .."/" .. package,
	license = "MIT",
}

dependencies = {
	"lua >= 5.1",
}

source = {
	url = "git://github.com/" .. user .. "/" .. package,
}

build = {
	type = "builtin",
}
