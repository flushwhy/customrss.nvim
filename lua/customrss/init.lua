---@class CustomRss.Plugin
--- Public API. This plugin is deliberately display-less: it fetches, parses,
--- sorts and caches feed entries, and fires `User` autocmds so you can wire
--- up whatever UI you like (telescope picker, floating window, statusline
--- count, whatever) instead of being handed one.
local M = {}

M.did_setup = false

---@type CustomRss.Entry[]
M.entries = {}

---@type { feed: CustomRss.FeedConfig, err: string }[]
M.errors = {}

---Setup the rss plugin
---@param opts? CustomRss.UserOptions plugin options
function M.setup(opts)
  if M.did_setup then
    local Util = require("customrss.util")
    return Util.warn("customrss.nvim is already setup")
  end
  M.did_setup = true
  require("customrss.config").setup(opts)
end

---@param entries CustomRss.Entry[]
---@param feed CustomRss.FeedConfig
---@param feed_title string?
local function tag_entries(entries, feed, feed_title)
  local name = feed.name or feed_title or feed.url
  for i, e in ipairs(entries) do
    e.feed_name = name
    e.feed_url = feed.url
    if not e.id or e.id == "" then
      -- Malformed feed missing both <guid>/<id> and <link>: fall back to a
      -- deterministic synthetic id so read-state persistence still works.
      e.id = feed.url .. "#" .. (e.link or e.title or tostring(i))
    end
  end
end

---Fetch every configured feed, parse, hydrate read/unread state, sort, and
---cache the result. Fires `User CustomRssUpdated` (data = { entries, errors }) so a
---display layer can subscribe instead of polling `get_entries()`.
---@param cb? fun(entries: CustomRss.Entry[], errors: { feed: CustomRss.FeedConfig, err: string }[])
---@param opts? { sort?: table } override config.sort for just this refresh
function M.refresh(cb, opts)
  local Util = require("customrss.util")
  if not M.did_setup then
    Util.error("customrss.nvim: call require('rss').setup() before refresh()")
    return
  end

  local Config = require("customrss.config")
  local Fetch = require("customrss.fetch")
  local Parse = require("customrss.parse")
  local State = require("customrss.state")
  local Sort = require("customrss.sort")

  if #Config.feeds == 0 then
    Util.warn("customrss.nvim: no feeds configured")
    M.entries, M.errors = {}, {}
    if cb then
      cb(M.entries, M.errors)
    end
    return
  end

  Fetch.fetch_all(Config.feeds, Config.fetch, function(results)
    local all_entries = {}
    local errors = {}

    for _, result in ipairs(results) do
      if result.ok then
        local ok, feed_title_or_err, entries = Parse.parse(result.body_or_err)
        if ok then
          tag_entries(entries, result.feed, feed_title_or_err)
          vim.list_extend(all_entries, entries)
        else
          table.insert(errors, { feed = result.feed, err = feed_title_or_err })
        end
      else
        table.insert(errors, { feed = result.feed, err = result.body_or_err })
      end
    end

    State.hydrate(all_entries)

    local sort_opts = (opts and opts.sort) or Config.sort
    Sort.sort(all_entries, sort_opts)

    M.entries = all_entries
    M.errors = errors

    if #errors > 0 then
      local lines = {}
      for _, e in ipairs(errors) do
        table.insert(lines, ("  - %s: %s"):format(e.feed.name or e.feed.url, e.err))
      end
      Util.warn(("customrss.nvim: %d/%d feed(s) failed:\n%s"):format(#errors, #results, table.concat(lines, "\n")))
    end

    vim.api.nvim_exec_autocmds("User", {
      pattern = "CustomRssUpdated",
      data = { entries = M.entries, errors = M.errors },
    })
    if cb then
      cb(M.entries, M.errors)
    end
  end)
end

---Return the cached entries from the last refresh(), optionally re-sorted
---in place without re-fetching anything over the network.
---@param opts? { sort?: table }
---@return CustomRss.Entry[]
function M.get_entries(opts)
  if opts and opts.sort then
    require("customrss.sort").sort(M.entries, opts.sort)
  end
  return M.entries
end

---@return { feed: CustomRss.FeedConfig, err: string }[] errors from the last refresh() (empty if none, or refresh() hasn't run yet)
function M.get_errors()
  return M.errors
end

---@param id string
function M.mark_read(id)
  require("customrss.state").mark_read(id)
  for _, e in ipairs(M.entries) do
    if e.id == id then
      e.read = true
      break
    end
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "CustomRssEntryRead", data = { id = id } })
end

---@param id string
function M.mark_unread(id)
  require("customrss.state").mark_unread(id)
  for _, e in ipairs(M.entries) do
    if e.id == id then
      e.read = false
      break
    end
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "CustomRssEntryUnread", data = { id = id } })
end

---Mark every currently cached entry as read.
function M.mark_all_read()
  local ids = {}
  for _, e in ipairs(M.entries) do
    table.insert(ids, e.id)
    e.read = true
  end
  require("customrss.state").mark_all_read(ids)
  vim.api.nvim_exec_autocmds("User", { pattern = "CustomRssAllRead", data = {} })
end

return M
