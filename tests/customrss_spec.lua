---@module 'luassert'

local CustomRss = require("customrss")
local Fetch = require("customrss.fetch")

local RSS_FEED_A = [==[
<rss version="2.0"><channel><title>Feed A</title>
  <item><title>A1</title><link>https://a.example/1</link><guid>a1</guid><pubDate>Tue, 22 Sep 2026 10:00:00 GMT</pubDate></item>
  <item><title>A2</title><link>https://a.example/2</link><guid>a2</guid><pubDate>Mon, 21 Sep 2026 10:00:00 GMT</pubDate></item>
</channel></rss>
]==]

local RSS_FEED_B = [==[
<rss version="2.0"><channel><title>Feed B</title>
  <item><title>B1</title><link>https://b.example/1</link><guid>b1</guid><pubDate>Wed, 23 Sep 2026 10:00:00 GMT</pubDate></item>
</channel></rss>
]==]

---Stub Fetch.fetch_all so tests never touch the network: it synchronously
---resolves each configured feed against a canned XML body by matching on URL.
---@param bodies table<string, string>
local function stub_fetch(bodies)
  Fetch.fetch_all = function(feeds, _opts, on_done)
    local results = {}
    for _, feed in ipairs(feeds) do
      local body = bodies[feed.url]
      if body then
        table.insert(results, { feed = feed, ok = true, body_or_err = body })
      else
        table.insert(results, { feed = feed, ok = false, body_or_err = "stub: no body for " .. feed.url })
      end
    end
    on_done(results)
  end
end

describe("customrss (end-to-end, fetch stubbed)", function()
  local original_fetch_all = Fetch.fetch_all
  local state_file = "/tmp/customrss-e2e-spec-state.json"

  before_each(function()
    os.remove(state_file)
    CustomRss.did_setup = false
    CustomRss.entries = {}
    CustomRss.errors = {}
    CustomRss.setup({
      feeds = {
        { url = "https://a.example/feed.xml" },
        { url = "https://b.example/feed.xml", name = "Feed B override" },
      },
      sort = { by = "date" },
      state_file = state_file,
    })
    stub_fetch({
      ["https://a.example/feed.xml"] = RSS_FEED_A,
      ["https://b.example/feed.xml"] = RSS_FEED_B,
    })
  end)

  after_each(function()
    Fetch.fetch_all = original_fetch_all
  end)

  it("errors instead of crashing when refresh() is called before setup()", function()
    CustomRss.did_setup = false
    assert.has_no.errors(function()
      CustomRss.refresh()
    end)
  end)

  it("fetches, parses, tags, and sorts entries from every feed", function()
    local got_entries, got_errors
    CustomRss.refresh(function(entries, errors)
      got_entries, got_errors = entries, errors
    end)

    assert.are.equal(0, #got_errors)
    assert.are.equal(3, #got_entries)
    -- sorted newest-first by date: B1 (23rd) > A1 (22nd) > A2 (21st)
    assert.are.equal("B1", got_entries[1].title)
    assert.are.equal("A1", got_entries[2].title)
    assert.are.equal("A2", got_entries[3].title)
  end)

  it("uses the config-supplied name over the feed's own <title>", function()
    CustomRss.refresh()
    local entries = CustomRss.get_entries()
    local b1
    for _, e in ipairs(entries) do
      if e.title == "B1" then
        b1 = e
      end
    end
    assert.are.equal("Feed B override", b1.feed_name)
  end)

  it("falls back to the feed's own <title> when no name is configured", function()
    CustomRss.refresh()
    local entries = CustomRss.get_entries()
    local a1
    for _, e in ipairs(entries) do
      if e.title == "A1" then
        a1 = e
      end
    end
    assert.are.equal("Feed A", a1.feed_name)
  end)

  it("records per-feed errors without losing the entries from feeds that succeeded", function()
    CustomRss.setup_called_twice_guard = nil
    stub_fetch({ ["https://a.example/feed.xml"] = RSS_FEED_A }) -- b.example now "fails"
    local got_entries, got_errors
    CustomRss.refresh(function(entries, errors)
      got_entries, got_errors = entries, errors
    end)
    assert.are.equal(1, #got_errors)
    assert.are.equal(2, #got_entries)
  end)

  it("get_entries() can re-sort the cached batch without re-fetching", function()
    CustomRss.refresh()
    local by_title = CustomRss.get_entries({ sort = { by = "title" } })
    assert.are.equal("A1", by_title[1].title)
    assert.are.equal("A2", by_title[2].title)
    assert.are.equal("B1", by_title[3].title)
  end)

  it("mark_read / mark_unread update both the cache and persisted state", function()
    CustomRss.refresh()
    local id = CustomRss.get_entries()[1].id
    CustomRss.mark_read(id)
    assert.is_true(require("customrss.state").is_read(id))
    CustomRss.mark_unread(id)
    assert.is_false(require("customrss.state").is_read(id))
  end)

  it("mark_all_read marks every cached entry", function()
    CustomRss.refresh()
    CustomRss.mark_all_read()
    for _, e in ipairs(CustomRss.get_entries()) do
      assert.is_true(e.read)
    end
  end)

  it("warns instead of erroring on setup() called twice", function()
    assert.has_no.errors(function()
      CustomRss.setup({})
    end)
  end)
end)
