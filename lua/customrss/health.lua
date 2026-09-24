---@class CustomRss.Health
local M = {}

local function check_curl()
  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl found in $PATH")
  else
    vim.health.error("curl not found in $PATH (required to fetch feeds)")
  end
end

local function check_vim_system()
  if vim.system then
    vim.health.ok("vim.system() available (Neovim >= 0.10)")
  else
    vim.health.error("vim.system() not available — customrss.nvim requires Neovim >= 0.10")
  end
end

local function check_feeds()
  local Config = require("customrss.config")
  local feeds = Config.feeds

  if type(feeds) ~= "table" or #feeds == 0 then
    vim.health.warn("no feeds configured (set opts.feeds in setup())")
    return
  end

  vim.health.ok(("%d feed(s) configured"):format(#feeds))

  for i, feed in ipairs(feeds) do
    if type(feed) ~= "table" or type(feed.url) ~= "string" or feed.url == "" then
      vim.health.error(("feeds[%d] is invalid: expected { url = string, name? = string }"):format(i))
    elseif not feed.url:match("^https?://") then
      vim.health.warn(("feeds[%d].url doesn't look like an http(s) URL: %s"):format(i, feed.url))
    end
  end
end

local function check_sort()
  local Config = require("customrss.config")
  local by = Config.sort and Config.sort.by
  local Sort = require("customrss.sort")
  if type(by) == "function" then
    vim.health.ok("sort.by is a custom function")
  elseif type(by) == "string" and Sort.factories[by] then
    vim.health.ok(("sort.by = %q"):format(by))
  else
    vim.health.error(("invalid sort.by: %s"):format(vim.inspect(by)))
  end
end

local function check_state_file()
  local Config = require("customrss.config")
  local path = Config.state_file
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 1 or vim.fn.mkdir(dir, "p") == 1 then
    vim.health.ok("state directory is writable: " .. dir)
  else
    vim.health.error("state directory could not be created: " .. dir)
  end
end

---Health check called by `:checkhealth customrss`
function M.check()
  vim.health.start("customrss.nvim")

  if require("customrss").did_setup then
    vim.health.ok("setup() was called")
  else
    vim.health.error("setup() was not called. Call require('customrss').setup({}) in your config.")
    return
  end

  check_vim_system()
  check_curl()
  check_feeds()
  check_sort()
  check_state_file()
end

return M
