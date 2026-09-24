---@meta _
--- Definition file for LuaLS type information. Not loaded at runtime.
--- See: https://luals.github.io/wiki/definition-files/

-- lua/rss/init.lua -------------------------------------------------------------

---@class CustomRss.Plugin
---@field did_setup boolean whether setup() has been called
---@field entries CustomRss.Entry[] cached entries from the last refresh()
---@field errors { feed: CustomRss.FeedConfig, err: string }[] per-feed failures from the last refresh()
---@field setup fun(opts?: CustomRss.UserOptions) setup the plugin with user options
---@field refresh fun(cb?: fun(entries: CustomRss.Entry[], errors: { feed: CustomRss.FeedConfig, err: string }[]), opts?: { sort?: table }) fetch, parse, sort and cache every configured feed
---@field get_entries fun(opts?: { sort?: table }): CustomRss.Entry[] cached entries, optionally re-sorted without re-fetching
---@field get_errors fun(): { feed: CustomRss.FeedConfig, err: string }[] per-feed failures from the last refresh()
---@field mark_read fun(id: string) mark one entry read (persisted)
---@field mark_unread fun(id: string) mark one entry unread (persisted)
---@field mark_all_read fun() mark every cached entry read (persisted)

--- Entries are tagged with their source feed and hydrated with the persisted
--- read/unread state before being handed to your display layer.
---@class CustomRss.Entry
---@field id string stable identifier (guid/id, falls back to link, then a synthetic id)
---@field feed_name string display name of the source feed (config name, else feed's own <title>, else url)
---@field feed_url string the feed's URL, as configured
---@field title string
---@field link? string
---@field author? string
---@field description? string raw HTML/text body (CDATA-unwrapped, entity-decoded), if the feed included one
---@field published? integer unix timestamp (UTC), nil if the feed's date couldn't be parsed
---@field published_raw? string the original, unparsed date string from the feed
---@field read boolean whether this entry has been marked read

-- lua/rss/config.lua -------------------------------------------------------------

---@class CustomRss.Config
---@field feeds CustomRss.FeedConfig[]
---@field sort { by: CustomRss.SortBy|fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean, order?: "asc"|"desc" }
---@field fetch { timeout: integer, concurrency: integer }
---@field state_file string path to the JSON file used to persist read/unread state
---@field augroup integer augroup created at module load
---@field setup fun(opts?: CustomRss.UserOptions) setup the plugin configuration

---@class CustomRss.FeedConfig
---@field url string the feed's URL (RSS 2.0 or Atom)
---@field name? string display name override; defaults to the feed's own <title>, then the URL

---@class CustomRss.UserOptions
---@field feeds? CustomRss.FeedConfig[]
---@field sort? { by?: CustomRss.SortBy|fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean, order?: "asc"|"desc" }
---@field fetch? { timeout?: integer, concurrency?: integer }
---@field state_file? string

---@class CustomRss.DefaultOptions
---@field feeds CustomRss.FeedConfig[]
---@field sort { by: CustomRss.SortBy, order: nil }
---@field fetch { timeout: integer, concurrency: integer }
---@field state_file string

-- lua/rss/sort.lua -------------------------------------------------------------

---@alias CustomRss.SortBy "date"|"feed"|"title"|"unread"

---@class CustomRss.Sort
---@field default_order table<CustomRss.SortBy, "asc"|"desc">
---@field factories table<CustomRss.SortBy, fun(ascending: boolean): fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean>
---@field sort fun(entries: CustomRss.Entry[], opts?: { by?: CustomRss.SortBy|fun(a: CustomRss.Entry, b: CustomRss.Entry): boolean, order?: "asc"|"desc" }): CustomRss.Entry[]

-- lua/rss/parse.lua -------------------------------------------------------------

---@class CustomRss.Parse
---@field parse fun(xml: string): boolean, string|CustomRss.Entry[], CustomRss.Entry[]? parse RSS 2.0 or Atom XML into (ok, feed_title|err, entries?)
---@field parse_date fun(str?: string): integer? parse an RFC822 or ISO8601 date into a unix timestamp
---@field parse_rfc822 fun(str?: string): integer?
---@field parse_iso8601 fun(str?: string): integer?

-- lua/rss/fetch.lua -------------------------------------------------------------

---@class CustomRss.Fetch
---@field fetch_all fun(feeds: CustomRss.FeedConfig[], opts: { timeout?: integer, concurrency?: integer }, on_done: fun(results: { feed: CustomRss.FeedConfig, ok: boolean, body_or_err: string }[]))

-- lua/rss/state.lua -------------------------------------------------------------

---@class CustomRss.State
---@field setup fun(path: string) configure the JSON file backing the read/unread store
---@field is_read fun(id: string): boolean
---@field mark_read fun(id: string)
---@field mark_unread fun(id: string)
---@field mark_all_read fun(ids: string[])
---@field hydrate fun(entries: CustomRss.Entry[]) set `entry.read` on every entry from persisted state

-- lua/rss/util.lua -------------------------------------------------------------

---@class CustomRss.Util
---@field notify fun(msg: string|table, level?: integer) send notification with plugin title
---@field info fun(msg: string) send info notification
---@field warn fun(msg: string) send warning notification
---@field error fun(msg: string) send error notification

-- lua/rss/health.lua -------------------------------------------------------------

---@class CustomRss.Health
---@field check fun() perform health check for the plugin
