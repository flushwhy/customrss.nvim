---@module 'luassert'

local parse = require("customrss.parse")

describe("customrss.parse", function()
  describe("RSS 2.0", function()
    local rss_xml = [==[
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example &amp; Blog</title>
    <link>https://example.com</link>
    <item>
      <title>Hello &lt;World&gt;</title>
      <link>https://example.com/1</link>
      <guid>urn:uuid:1</guid>
      <pubDate>Tue, 22 Sep 2026 10:00:00 GMT</pubDate>
      <description><![CDATA[<p>Some <b>html</b> body</p>]]></description>
      <dc:creator>Jane Doe</dc:creator>
    </item>
    <item>
      <title>Second post</title>
      <link>https://example.com/2</link>
      <guid>urn:uuid:2</guid>
      <pubDate>Mon, 21 Sep 2026 08:30:00 +0000</pubDate>
      <description>Plain text body</description>
    </item>
  </channel>
</rss>
]==]

    local ok, feed_title, entries = parse.parse(rss_xml)

    it("parses successfully", function()
      assert.is_true(ok)
    end)

    it("decodes the feed title", function()
      assert.are.equal("Example & Blog", feed_title)
    end)

    it("finds every item", function()
      assert.are.equal(2, #entries)
    end)

    it("decodes entities in item titles", function()
      assert.are.equal("Hello <World>", entries[1].title)
    end)

    it("extracts the link", function()
      assert.are.equal("https://example.com/1", entries[1].link)
    end)

    it("uses guid as the id", function()
      assert.are.equal("urn:uuid:1", entries[1].id)
    end)

    it("unwraps CDATA in the description", function()
      assert.are.equal("<p>Some <b>html</b> body</p>", entries[1].description)
    end)

    it("falls back to dc:creator for the author", function()
      assert.are.equal("Jane Doe", entries[1].author)
    end)

    it("parses a numeric-offset pubDate", function()
      assert.is_not_nil(entries[2].published)
    end)

    it("orders dates correctly (item 1 is newer than item 2)", function()
      assert.is_true(entries[1].published > entries[2].published)
    end)
  end)

  describe("Atom", function()
    local atom_xml = [==[
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Example</title>
  <entry>
    <title>Atom entry one</title>
    <link href="https://example.org/a1" rel="alternate"/>
    <id>tag:example.org,2026:a1</id>
    <updated>2026-09-20T12:00:00Z</updated>
    <author><name>Bob</name></author>
    <summary>Summary text</summary>
  </entry>
  <entry>
    <title>Atom entry two</title>
    <link href="https://example.org/a2"/>
    <id>tag:example.org,2026:a2</id>
    <published>2026-09-19T09:15:00+02:00</published>
    <content>Content text</content>
  </entry>
</feed>
]==]

    local ok, feed_title, entries = parse.parse(atom_xml)

    it("parses successfully", function()
      assert.is_true(ok)
    end)

    it("reads the feed title", function()
      assert.are.equal("Atom Example", feed_title)
    end)

    it("finds every entry", function()
      assert.are.equal(2, #entries)
    end)

    it("extracts the href link attribute", function()
      assert.are.equal("https://example.org/a1", entries[1].link)
    end)

    it("reads the author name", function()
      assert.are.equal("Bob", entries[1].author)
    end)

    it("falls back to <content> when there's no <summary>", function()
      assert.are.equal("Content text", entries[2].description)
    end)

    it("parses a timezone-offset <published> date", function()
      assert.is_not_nil(entries[2].published)
    end)
  end)

  describe("date parsing", function()
    it("treats the unix epoch as 0, in ISO8601", function()
      assert.are.equal(0, parse.parse_date("1970-01-01T00:00:00Z"))
    end)

    it("treats the unix epoch as 0, in RFC822", function()
      assert.are.equal(0, parse.parse_date("Thu, 01 Jan 1970 00:00:00 GMT"))
    end)

    it("handles dates before 1970 (negative timestamps)", function()
      assert.are.equal(-86400, parse.parse_date("1969-12-31T00:00:00Z"))
    end)

    it("computes exactly 86400 seconds between consecutive days", function()
      local a = parse.parse_date("2026-09-22T10:00:00Z")
      local b = parse.parse_date("2026-09-21T10:00:00Z")
      assert.are.equal(86400, a - b)
    end)

    it("returns nil for garbage input", function()
      assert.is_nil(parse.parse_date("not a date"))
    end)
  end)

  describe("error handling", function()
    it("fails gracefully on empty input", function()
      local ok = parse.parse("")
      assert.is_false(ok)
    end)

    it("fails gracefully on non-feed HTML", function()
      local ok = parse.parse("<html><body>not a feed</body></html>")
      assert.is_false(ok)
    end)
  end)
end)
