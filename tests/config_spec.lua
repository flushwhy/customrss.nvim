---@module 'luassert'

local Config = require("customrss.config")

describe("customrss.config", function()
  it("starts with no feeds configured", function()
    assert.are.equal(0, #Config.feeds)
  end)

  it("accepts valid feeds and sort options", function()
    Config.setup({
      feeds = { { url = "https://example.com/feed.xml", name = "Example" } },
      sort = { by = "unread", order = "asc" },
    })
    assert.are.equal(1, #Config.feeds)
    assert.are.equal("Example", Config.feeds[1].name)
    assert.are.equal("unread", Config.sort.by)
    assert.are.equal("asc", Config.sort.order)
  end)

  it("falls back to default feeds when given something that isn't a list", function()
    Config.setup({ feeds = "not-a-list" })
    assert.are.equal(0, #Config.feeds)
  end)

  it("falls back to default feeds when a feed is missing a url", function()
    Config.setup({ feeds = { { name = "No URL" } } })
    assert.are.equal(0, #Config.feeds)
  end)

  it("falls back to the default sort.by on an unknown strategy name", function()
    Config.setup({ sort = { by = "bogus" } })
    assert.are.equal("date", Config.sort.by)
  end)

  it("accepts a function for sort.by", function()
    local cmp = function(a, b)
      return a.title < b.title
    end
    Config.setup({ sort = { by = cmp } })
    assert.are.equal(cmp, Config.sort.by)
  end)

  it("falls back to default fetch options when given garbage", function()
    Config.setup({ fetch = { timeout = "not-a-number" } })
    assert.are.equal(10000, Config.fetch.timeout)
    assert.are.equal(5, Config.fetch.concurrency)
  end)

  it("falls back to the default state_file on an empty string", function()
    Config.setup({ state_file = "" })
    assert.is_true(#Config.state_file > 0)
  end)

  it("accepts a custom state_file", function()
    Config.setup({ state_file = "/tmp/customrss-config-spec-state.json" })
    assert.are.equal("/tmp/customrss-config-spec-state.json", Config.state_file)
  end)
end)
