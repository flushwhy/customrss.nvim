---@class CustomRss.Parse
--- Pure-Lua RSS 2.0 / Atom feed parser.
--- Deliberately has ZERO `vim.*` calls so it can be required and unit-tested
--- with a plain `lua` interpreter, independently of Neovim.
local M = {}

-- ---------------------------------------------------------------------------
-- XML text helpers
-- ---------------------------------------------------------------------------

local ENTITIES = {
  ["&amp;"] = "&",
  ["&lt;"] = "<",
  ["&gt;"] = ">",
  ["&quot;"] = '"',
  ["&apos;"] = "'",
}

---Decode XML entities (named + numeric) in a string.
---@param str string
---@return string
function M.decode_entities(str)
  if not str then
    return str
  end
  str = str:gsub("&#x(%x+);", function(hex)
    local n = tonumber(hex, 16)
    return n and utf8.char(n) or ""
  end)
  str = str:gsub("&#(%d+);", function(dec)
    local n = tonumber(dec)
    return n and utf8.char(n) or ""
  end)
  str = str:gsub("&%a+;", ENTITIES)
  return str
end

---Strip CDATA wrapper and decode entities, trim surrounding whitespace.
---@param str? string
---@return string?
local function clean_text(str)
  if str == nil then
    return nil
  end
  local cdata = str:match("^%s*<!%[CDATA%[(.-)%]%]>%s*$")
  if cdata then
    str = cdata
  else
    str = M.decode_entities(str)
  end
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  if str == "" then
    return nil
  end
  return str
end
M.clean_text = clean_text

---Extract the (first, non-greedy) inner text of `<tag>...</tag>` from `content`.
---Handles both self-closed-less normal tags and tags carrying attributes,
---e.g. `<title type="text">...</title>`.
---@param content string
---@param tag string
---@return string?
local function extract_tag(content, tag)
  local raw = content:match("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">")
  return clean_text(raw)
end
M.extract_tag = extract_tag

---Extract an attribute value from the first occurrence of `<tag ...>`.
---@param content string
---@param tag string
---@param attr string
---@return string?
local function extract_attr(content, tag, attr)
  local tag_open = content:match("<" .. tag .. "%s+[^>]->")
  if not tag_open then
    return nil
  end
  local val = tag_open:match(attr .. '%s*=%s*"(.-)"') or tag_open:match(attr .. "%s*=%s*'(.-)'")
  return clean_text(val)
end
M.extract_attr = extract_attr

---Split `content` into the raw inner-text of every top-level `<tag>...</tag>` block.
---@param content string
---@param tag string
---@return string[]
local function extract_blocks(content, tag)
  local blocks = {}
  for block in content:gmatch("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">") do
    table.insert(blocks, block)
  end
  return blocks
end
M.extract_blocks = extract_blocks

-- ---------------------------------------------------------------------------
-- Date parsing -> unix timestamp (UTC), independent of os.time()'s local tz
-- ---------------------------------------------------------------------------

local MONTHS = {
  Jan = 1,
  Feb = 2,
  Mar = 3,
  Apr = 4,
  May = 5,
  Jun = 6,
  Jul = 7,
  Aug = 8,
  Sep = 9,
  Oct = 10,
  Nov = 11,
  Dec = 12,
}

---Days since 1970-01-01 for a given proleptic-Gregorian y/m/d (Howard Hinnant's algorithm).
---@param y integer
---@param m integer
---@param d integer
---@return integer
local function days_from_civil(y, m, d)
  y = m <= 2 and y - 1 or y
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400                                      -- [0, 399]
  local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1 -- [0, 365]
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy            -- [0, 146096]
  return era * 146097 + doe - 719468
end

---@param y integer
---@param mo integer
---@param d integer
---@param h integer
---@param mi integer
---@param s integer
---@param offset_sec integer seconds to SUBTRACT to normalize to UTC (i.e. the timezone offset from UTC)
---@return integer
local function to_unix(y, mo, d, h, mi, s, offset_sec)
  local days = days_from_civil(y, mo, d)
  return days * 86400 + h * 3600 + mi * 60 + s - offset_sec
end

---Parse a numeric or named timezone suffix into an offset-from-UTC in seconds.
---@param tz? string
---@return integer
local function parse_tz_offset(tz)
  if not tz or tz == "" then
    return 0
  end
  if tz == "Z" or tz == "z" then
    return 0
  end
  if tz == "UT" or tz == "UTC" or tz == "GMT" then
    return 0
  end
  local named = { EST = -5, EDT = -4, CST = -6, CDT = -5, MST = -7, MDT = -6, PST = -8, PDT = -7 }
  if named[tz] then
    return named[tz] * 3600
  end
  local sign, hh, mm = tz:match("([%+%-])(%d%d):?(%d%d)")
  if sign then
    local off = tonumber(hh) * 3600 + tonumber(mm) * 60
    return sign == "-" and -off or off
  end
  return 0
end

---Parse an RFC822/RFC2822 date, e.g. "Tue, 22 Sep 2026 10:00:00 GMT" or "+0000".
---@param str? string
---@return integer?
function M.parse_rfc822(str)
  if not str then
    return nil
  end
  local d, mon, y, h, mi, s, tz = str:match("(%d%d?)%s+(%a+)%s+(%d%d%d?%d?)%s+(%d%d?):(%d%d):?(%d?%d?)%s*(%S*)")
  if not d then
    return nil
  end
  local month = MONTHS[mon:sub(1, 1):upper() .. mon:sub(2, 3):lower()]
  if not month then
    return nil
  end
  local year = tonumber(y)
  if year < 100 then
    year = year + (year < 70 and 2000 or 1900)
  end
  local sec = tonumber(s) or 0
  local offset = parse_tz_offset(tz)
  local ok, ts = pcall(to_unix, year, month, tonumber(d), tonumber(h), tonumber(mi), sec, offset)
  return ok and ts or nil
end

---Parse an ISO 8601 date, e.g. "2026-09-22T10:00:00Z" or "...+02:00".
---@param str? string
---@return integer?
function M.parse_iso8601(str)
  if not str then
    return nil
  end
  local y, mo, d, h, mi, s, tz = str:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):?(%d?%d?)(%S*)")
  if not y then
    return nil
  end
  local sec = tonumber(s) or 0
  local offset = parse_tz_offset(tz)
  local ok, ts = pcall(to_unix, tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), sec, offset)
  return ok and ts or nil
end

---Try RFC822 then ISO8601.
---@param str? string
---@return integer?
function M.parse_date(str)
  if not str then
    return nil
  end
  return M.parse_rfc822(str) or M.parse_iso8601(str)
end

-- ---------------------------------------------------------------------------
-- RSS 2.0
-- ---------------------------------------------------------------------------

---@param item string
---@return CustomRss.Entry
local function parse_rss_item(item)
  local link = extract_tag(item, "link")
  local guid = extract_tag(item, "guid")
  local description = extract_tag(item, "description") or extract_tag(item, "content:encoded")
  local author = extract_tag(item, "author") or extract_tag(item, "dc:creator")
  local pub = extract_tag(item, "pubDate") or extract_tag(item, "dc:date")
  return {
    id = guid or link,
    title = extract_tag(item, "title") or "(untitled)",
    link = link,
    author = author,
    description = description,
    published = M.parse_date(pub),
    published_raw = pub,
  }
end

---@param xml string
---@return string? feed_title
---@return CustomRss.Entry[] entries
local function parse_rss(xml)
  local channel = xml:match("<channel>(.-)</channel>") or xml
  local feed_title = extract_tag(channel, "title")
  local entries = {}
  for _, item in ipairs(extract_blocks(channel, "item")) do
    table.insert(entries, parse_rss_item(item))
  end
  return feed_title, entries
end

-- ---------------------------------------------------------------------------
-- Atom
-- ---------------------------------------------------------------------------

---@param entry string
---@return CustomRss.Entry
local function parse_atom_entry(entry)
  local link = extract_attr(entry, "link", "href")
  if not link then
    -- fall back to a bare <link>text</link>, rare but seen in the wild
    link = extract_tag(entry, "link")
  end
  local author = entry:match("<author>(.-)</author>")
  if author then
    author = extract_tag(author, "name") or clean_text(author)
  end
  local pub = extract_tag(entry, "published") or extract_tag(entry, "updated")
  return {
    id = extract_tag(entry, "id") or link,
    title = extract_tag(entry, "title") or "(untitled)",
    link = link,
    author = author,
    description = extract_tag(entry, "summary") or extract_tag(entry, "content"),
    published = M.parse_date(pub),
    published_raw = pub,
  }
end

---@param xml string
---@return string? feed_title
---@return CustomRss.Entry[] entries
local function parse_atom(xml)
  local feed_block = xml:match("<feed[^>]*>(.-)</feed>") or xml
  local feed_title = extract_tag(feed_block, "title")
  local entries = {}
  for _, entry in ipairs(extract_blocks(feed_block, "entry")) do
    table.insert(entries, parse_atom_entry(entry))
  end
  return feed_title, entries
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Parse raw feed XML (RSS 2.0 or Atom, auto-detected) into a normalized entry list.
---@param xml string
---@return boolean ok
---@return string|CustomRss.Entry[] feed_title_or_err
---@return CustomRss.Entry[]? entries
function M.parse(xml)
  if type(xml) ~= "string" or xml:match("^%s*$") then
    return false, "empty response body"
  end
  local feed_title, entries
  if
      xml:find("<entry", 1, true)
      and (xml:find("<feed", 1, true) or xml:find('xmlns="http://www.w3.org/2005/Atom"', 1, true))
  then
    feed_title, entries = parse_atom(xml)
  elseif xml:find("<item", 1, true) or xml:find("<channel", 1, true) or xml:find("<rss", 1, true) then
    feed_title, entries = parse_rss(xml)
  elseif xml:find("<feed", 1, true) then
    feed_title, entries = parse_atom(xml)
  else
    return false, "unrecognized feed format (not RSS 2.0 or Atom)"
  end
  return true, feed_title, entries
end

return M
