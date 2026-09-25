---@module 'luassert'

local State = require("customrss.state")

local STATE_FILE = "/tmp/customrss-state-spec.json"

describe("customrss.state", function()
  before_each(function()
    os.remove(STATE_FILE)
    State._reset()
    State.setup(STATE_FILE)
  end)

  it("treats an unmarked entry as unread", function()
    assert.is_false(State.is_read("a"))
  end)

  it("marks an entry read", function()
    State.mark_read("a")
    assert.is_true(State.is_read("a"))
  end)

  it("persists read state to disk across a reload", function()
    State.mark_read("a")
    State._reset() -- simulate a fresh Neovim session re-requiring the module
    State.setup(STATE_FILE)
    assert.is_true(State.is_read("a"))
  end)

  it("marks an entry unread again", function()
    State.mark_read("a")
    State.mark_unread("a")
    assert.is_false(State.is_read("a"))
  end)

  it("marks every id in a batch as read", function()
    State.mark_all_read({ "a", "b", "c" })
    assert.is_true(State.is_read("a"))
    assert.is_true(State.is_read("b"))
    assert.is_true(State.is_read("c"))
  end)

  it("hydrate() sets entry.read from persisted state", function()
    State.mark_all_read({ "a", "b" })
    local entries = { { id = "a", title = "A" }, { id = "b", title = "B" }, { id = "c", title = "C" } }
    State.hydrate(entries)
    assert.is_true(entries[1].read)
    assert.is_true(entries[2].read)
    assert.is_false(entries[3].read)
  end)
end)
