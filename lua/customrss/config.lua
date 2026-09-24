---@class CustomRss.Config
local M = {}

---@class CustomRss.DefaultOptions
local defaults = {
  ---@type CustomRss.FeedConfig[]
  feeds = {},

  sort = {
    ---@type CustomRss.SortBy|fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean
    by = "date",
    ---@type "asc"|"desc"|nil  nil = use the natural default for `by` (see rss.sort.default_order)
    order = nil,
  },

  fetch = {
    timeout = 10000, -- ms, per feed
    concurrency = 5, -- max simultaneous curl jobs
  },

  -- Where read/unread state is persisted between sessions.
  state_file = vim.fn.stdpath("data") .. "/customrss.nvim/state.json",
}

-- Access config values directly: Config.feeds, Config.sort, etc.
local config = vim.deepcopy(defaults)

-- Created at module load — available even before setup(), handy for consumers
-- that want to hook their own autocmds into the same group.
M.augroup = vim.api.nvim_create_augroup("customrss.nvim", { clear = true })

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

---@param feeds any
---@return boolean ok
---@return string? err
local function validate_feeds(feeds)
  if type(feeds) ~= "table" then
    return false, "expected a list of feeds"
  end
  for i, feed in ipairs(feeds) do
    if type(feed) ~= "table" or type(feed.url) ~= "string" or feed.url == "" then
      return false, ("feeds[%d] must be a table with a non-empty string 'url'"):format(i)
    end
    if feed.name ~= nil and type(feed.name) ~= "string" then
      return false, ("feeds[%d].name must be a string if given"):format(i)
    end
  end
  return true
end

---@param sort any
---@return boolean ok
---@return string? err
local function validate_sort(sort)
  if type(sort) ~= "table" then
    return false, "expected sort to be a table"
  end
  if sort.by ~= nil and type(sort.by) ~= "string" and type(sort.by) ~= "function" then
    return false, "sort.by must be a string or a function"
  end
  if type(sort.by) == "string" then
    local Sort = require("customrss.sort")
    if not Sort.factories[sort.by] then
      return false, ("sort.by %q is not one of: date, feed, title, unread"):format(sort.by)
    end
  end
  if sort.order ~= nil and sort.order ~= "asc" and sort.order ~= "desc" then
    return false, "sort.order must be 'asc' or 'desc'"
  end
  return true
end

---Extend the defaults options table with the user options
---@param opts? CustomRss.UserOptions plugin options
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, vim.deepcopy(defaults), opts or {})

  local Util = require("customrss.util")

  local ok_feeds, err_feeds = validate_feeds(config.feeds)
  if not ok_feeds then
    Util.error("Invalid 'feeds' option: " .. err_feeds)
    config.feeds = vim.deepcopy(defaults.feeds)
  end

  local ok_sort, err_sort = validate_sort(config.sort)
  if not ok_sort then
    Util.error("Invalid 'sort' option: " .. err_sort)
    config.sort = vim.deepcopy(defaults.sort)
  end

  if
    type(config.fetch) ~= "table"
    or type(config.fetch.timeout) ~= "number"
    or type(config.fetch.concurrency) ~= "number"
  then
    Util.error("Invalid 'fetch' option: expected { timeout = number, concurrency = number }")
    config.fetch = vim.deepcopy(defaults.fetch)
  end

  if type(config.state_file) ~= "string" or config.state_file == "" then
    Util.error("Invalid 'state_file' option: expected a non-empty string")
    config.state_file = defaults.state_file
  end

  require("customrss.state").setup(config.state_file)
end

return M