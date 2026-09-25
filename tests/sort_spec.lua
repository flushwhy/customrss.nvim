---@module 'luassert'

local sort = require("customrss.sort")

local function make_entries()
  return {
    { title = "B", feed_name = "Zeta", published = 100, read = true },
    { title = "A", feed_name = "Alpha", published = 300, read = false },
    { title = "C", feed_name = "Alpha", published = nil, read = false },
    { title = "D", feed_name = "Beta", published = 200, read = true },
  }
end

local function titles(entries)
  local t = {}
  for _, e in ipairs(entries) do
    table.insert(t, e.title)
  end
  return table.concat(t, ",")
end

describe("customrss.sort", function()
  describe("by = 'date'", function()
    it("defaults to newest first, with undated entries last", function()
      assert.are.equal("A,D,B,C", titles(sort.sort(make_entries(), { by = "date" })))
    end)

    it("order = 'asc' puts oldest first, but undated entries STILL last", function()
      assert.are.equal("B,D,A,C", titles(sort.sort(make_entries(), { by = "date", order = "asc" })))
    end)
  end)

  describe("by = 'feed'", function()
    it("defaults to A-Z by feed, with ties broken by title A-Z", function()
      assert.are.equal("A,C,D,B", titles(sort.sort(make_entries(), { by = "feed" })))
    end)

    it("order = 'desc' reverses the feed order but keeps ties A-Z by title", function()
      assert.are.equal("B,D,A,C", titles(sort.sort(make_entries(), { by = "feed", order = "desc" })))
    end)
  end)

  describe("by = 'title'", function()
    it("defaults to A-Z", function()
      assert.are.equal("A,B,C,D", titles(sort.sort(make_entries(), { by = "title" })))
    end)

    it("order = 'desc' reverses it", function()
      assert.are.equal("D,C,B,A", titles(sort.sort(make_entries(), { by = "title", order = "desc" })))
    end)
  end)

  describe("by = 'unread'", function()
    it("defaults to unread first, ties broken by newest date first", function()
      assert.are.equal("A,C,D,B", titles(sort.sort(make_entries(), { by = "unread" })))
    end)

    it("order = 'desc' puts read entries first instead", function()
      assert.are.equal("D,B,A,C", titles(sort.sort(make_entries(), { by = "unread", order = "desc" })))
    end)
  end)

  describe("by = a custom comparator function", function()
    it("runs the given comparator instead of a named strategy", function()
      local entries = make_entries()
      sort.sort(entries, {
        by = function(a, b)
          return #a.title < #b.title
        end,
      })
      assert.are.equal(4, #entries)
    end)
  end)

  describe("invalid input", function()
    it("errors on an unknown sort.by string", function()
      assert.has_error(function()
        sort.sort(make_entries(), { by = "bogus" })
      end)
    end)
  end)
end)
