# customrss.nvim

A tiny, display-less RSS/Atom middleware for Neovim. You give it feed URLs
and a sort preference; it fetches, parses, sorts, and caches entries, and
fires autocmds so *you* build the display however you want (floating
window, Telescope picker, statusline count, whatever).

No plugin dependencies — just the `curl` binary (which you already have)
and Neovim >= 0.10 (for `vim.system`).

## Setup

```lua
require("customrss").setup({
  feeds = {
    { url = "https://neovim.io/news.xml" },                 -- name inferred from the feed's <title>
    { url = "https://github.blog/feed/", name = "GitHub" }, -- or override it
  },
  sort = {
    by = "date",    -- "date" | "feed" | "title" | "unread" | function(a, b) -> boolean
    order = "desc", -- "asc" | "desc"; omit to use the natural default for `by`
  },
  fetch = {
    timeout = 10000, -- ms per feed
    concurrency = 5,  -- max simultaneous curl jobs
  },
  state_file = vim.fn.stdpath("data") .. "/customrss.nvim/state.json", -- read/unread persistence
})
```

Sort defaults per `by`, if `order` is omitted: `date` → newest first,
`feed`/`title` → A→Z, `unread` → unread first. Entries with no parseable date
always sort last, regardless of direction.

## API

```lua
local CustomRss = require("customrss")

-- Fetch + parse + sort every configured feed, then cache the result.
CustomRss.refresh(function(entries, errors)
  -- entries: CustomRss.Entry[], already sorted per config (or per opts.sort below)
  -- errors: { feed, err }[] for any feed that failed to fetch/parse
end)

-- Re-sort the last cached batch without hitting the network again.
CustomRss.refresh(cb, { sort = { by = "unread" } })
local entries = CustomRss.get_entries({ sort = { by = "title" } })

-- Read the cache directly (e.g. on startup, before the first refresh).
CustomRss.get_entries()
CustomRss.get_errors()

-- Read/unread state, persisted to `state_file`.
CustomRss.mark_read(entry.id)
CustomRss.mark_unread(entry.id)
CustomRss.mark_all_read()
```

### `CustomRss.Entry`

```lua
{
  id = "...",             -- stable id: guid/id, else link, else a synthetic fallback
  feed_name = "...",      -- config name, else the feed's own <title>, else the URL
  feed_url = "...",
  title = "...",
  link = "...",           -- may be nil for malformed entries
  author = "...",         -- may be nil
  description = "...",    -- raw HTML/text body, entity-decoded, CDATA-unwrapped
  published = 1758531600, -- unix timestamp (UTC), or nil if unparseable
  published_raw = "...",  -- the feed's original date string
  read = false,
}
```

## Events

Subscribe to these instead of polling, to build your own display:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "CustomRssUpdated", -- data = { entries, errors }
  callback = function(args)
    render(args.data.entries)
  end,
})
```

Also fired: `CustomRssEntryRead` (`data = { id }`), `CustomRssEntryUnread` (`data = { id }`),
`CustomRssAllRead`.

## Commands

- `:CustomRss refresh` — fetch every configured feed
- `:CustomRss mark_all_read`

## Health

`:checkhealth customrss` verifies `curl`, `vim.system`, your feed config, sort
config, and that the state directory is writable.
