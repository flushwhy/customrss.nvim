---@class CustomRss.State
--- Persists which entry ids have been marked read, across sessions.
--- Storage is a flat JSON object of `{ [entry_id] = true }` for read entries.
local M = {}

---@type table<string, true>
local read_ids = {}
local loaded = false
local file_path = nil ---@type string?

---@param path string
function M.setup(path)
	file_path = path
end

local function ensure_loaded()
	if loaded then
		return
	end
	loaded = true
	if not file_path then
		return
	end
	local f = io.open(file_path, "r")
	if not f then
		return
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return
	end
	local ok, decoded = pcall(vim.json.decode, content)
	if ok and type(decoded) == "table" then
		read_ids = decoded
	end
end

---@return boolean ok
---@return string? err
local function save()
	if not file_path then
		return false, "customrss.nvim: state file path not configured"
	end
	local dir = vim.fn.fnamemodify(file_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	local ok, encoded = pcall(vim.json.encode, read_ids)
	if not ok then
		return false, "customrss.nvim: failed to encode state: " .. tostring(encoded)
	end
	local f, err = io.open(file_path, "w")
	if not f then
		return false, "customrss.nvim: failed to write state file: " .. tostring(err)
	end
	f:write(encoded)
	f:close()
	return true
end
M._save = save -- exposed for tests

---@param id string
---@return boolean
function M.is_read(id)
	ensure_loaded()
	return read_ids[id] == true
end

---@param id string
function M.mark_read(id)
	ensure_loaded()
	if read_ids[id] ~= true then
		read_ids[id] = true
		save()
	end
end

---@param id string
function M.mark_unread(id)
	ensure_loaded()
	if read_ids[id] ~= nil then
		read_ids[id] = nil
		save()
	end
end

---@param ids string[]
function M.mark_all_read(ids)
	ensure_loaded()
	for _, id in ipairs(ids) do
		read_ids[id] = true
	end
	save()
end

---Apply stored read state onto a freshly parsed entry list (sets `entry.read`).
---@param entries CustomRss.Entry[]
function M.hydrate(entries)
	ensure_loaded()
	for _, e in ipairs(entries) do
		e.read = read_ids[e.id] == true
	end
end

--- Testing/debug helpers.
function M._reset()
	read_ids = {}
	loaded = false
end

return M
