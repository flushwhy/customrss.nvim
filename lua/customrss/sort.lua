---@class CustomRss.Sort
--- Pure-Lua sorting for `CustomRss.Entry` lists. No `vim.*` calls, unit-testable standalone.
local M = {}

---@alias CustomRss.SortBy "date"|"feed"|"title"|"unread"
---@alias CustomRss.SortComparator fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean

---@class CustomRss.SortOpts
---@field by? CustomRss.SortBy|CustomRss.SortComparator
---@field order? "asc"|"desc"

-- Each sort type has a different "natural" default direction: newest-first
-- for dates, A-Z for feed/title, unread-first for unread. `order` overrides it.
M.default_order = { date = "desc", feed = "asc", title = "asc", unread = "asc" }

---@param a integer?
---@param b integer?
---@param ascending boolean
---@return boolean # true if `a` sorts before `b`
local function date_lt(a, b, ascending)
	-- Entries with no parseable date always sort last, in either direction,
	-- so an undated entry never jumps to the top under "asc".
	if a == nil and b == nil then
		return false
	elseif a == nil then
		return false
	elseif b == nil then
		return true
	end
	if ascending then
		return a < b
	end
	return a > b
end

---@param a string
---@param b string
---@param ascending boolean
---@return boolean
local function str_lt(a, b, ascending)
	if ascending then
		return a < b
	end
	return a > b
end

---@type table<CustomRss.SortBy, fun(ascending: boolean): fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean>
local FACTORIES = {
	date = function(ascending)
		return function(a, b)
			return date_lt(a.published, b.published, ascending)
		end
	end,

	feed = function(ascending)
		return function(a, b)
			local fa, fb = a.feed_name or "", b.feed_name or ""
			if fa == fb then
				return str_lt(a.title or "", b.title or "", true) -- secondary key always A-Z
			end
			return str_lt(fa, fb, ascending)
		end
	end,

	title = function(ascending)
		return function(a, b)
			return str_lt(a.title or "", b.title or "", ascending)
		end
	end,

	unread = function(ascending)
		return function(a, b)
			if a.read ~= b.read then
				local unread_first = ascending
				if unread_first then
					return not a.read
				end
				return a.read
			end
			return date_lt(a.published, b.published, false) -- secondary key: newest first
		end
	end,
}

M.factories = FACTORIES

---Sort a list of entries in place and return it.
---@param entries CustomRss.Entry[]
---@param opts? CustomRss.SortOpts
---@return CustomRss.Entry[] entries the same table, sorted, for chaining
function M.sort(entries, opts)
	opts = opts or {}
	local by = opts.by or "date"

	if type(by) == "function" then
		table.sort(entries, by)
		if opts.order == "desc" then
			local n = #entries
			for i = 1, math.floor(n / 2) do
				entries[i], entries[n - i + 1] = entries[n - i + 1], entries[i]
			end
		end
		return entries
	end

	local factory = FACTORIES[by]
	if not factory then
		error(
			("customrss.nvim: unknown sort.by %q (expected one of: date, feed, title, unread, or a function)"):format(
				tostring(by)
			)
		)
	end
	local order = opts.order or M.default_order[by]
	table.sort(entries, factory(order == "asc"))
	return entries
end

return M
