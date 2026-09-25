---@module 'luassert'

local CustomRss = require("customrss")
local health = require("customrss.health")

describe("customrss.health", function()
  it("reports an error (not a crash) when setup() hasn't been called", function()
    CustomRss.did_setup = false
    assert.has_no.errors(function()
      health.check()
    end)
  end)

  it("runs clean with a default config", function()
    CustomRss.did_setup = false
    CustomRss.setup({})
    assert.has_no.errors(function()
      health.check()
    end)
  end)

  it("runs clean with feeds and a custom sort configured", function()
    CustomRss.did_setup = false
    CustomRss.setup({
      feeds = { { url = "https://example.com/feed.xml" } },
      sort = { by = "title" },
    })
    assert.has_no.errors(function()
      health.check()
    end)
  end)

  it("does not crash even when the config was invalid at setup time", function()
    CustomRss.did_setup = false
    CustomRss.setup({ feeds = "not-a-list", sort = { by = "bogus" } })
    assert.has_no.errors(function()
      health.check()
    end)
  end)
end)
