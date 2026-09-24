---@class CustomRss.Fetch
--- Async HTTP fetch for feed URLs, via the `curl` binary through `vim.system`.
--- No plugin dependencies (no plenary) — just curl, which is already on
--- virtually every machine running Neovim.
local M = {}

---@param url string
---@param timeout_ms integer
---@param cb fun(ok: boolean, body_or_err: string)
local function curl_get(url, timeout_ms, cb)
	if vim.fn.executable("curl") == 0 then
		return cb(false, "curl executable not found in $PATH")
	end
	local timeout_sec = math.max(1, math.ceil(timeout_ms / 1000))
	vim.system({
		"curl",
		"--silent",
		"--show-error",
		"--location",
		"--max-time",
		tostring(timeout_sec),
		"--user-agent",
		"customrss.nvim",
		url,
	}, { text = true }, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				cb(false, ("curl exited with code %d: %s"):format(res.code, vim.trim(res.stderr or "")))
			elseif not res.stdout or vim.trim(res.stdout) == "" then
				cb(false, "empty response body")
			else
				cb(true, res.stdout)
			end
		end)
	end)
end
M._curl_get = curl_get -- exposed for tests/mocking

---Fetch multiple feeds with bounded concurrency, calling `on_done` exactly once
---after every feed has either succeeded or failed.
---@param feeds CustomRss.FeedConfig[]
---@param opts { timeout?: integer, concurrency?: integer }
---@param on_done fun(results: { feed: CustomRss.FeedConfig, ok: boolean, body_or_err: string }[])
function M.fetch_all(feeds, opts, on_done)
	opts = opts or {}
	local results = {}

	if #feeds == 0 then
		return on_done(results)
	end

	local next_idx = 1
	local in_flight = 0
	local remaining = #feeds
	local concurrency = math.max(1, opts.concurrency or 5)

	local function start_next()
		while in_flight < concurrency and next_idx <= #feeds do
			local feed = feeds[next_idx]
			next_idx = next_idx + 1
			in_flight = in_flight + 1
			curl_get(feed.url, opts.timeout or 10000, function(ok, body_or_err)
				table.insert(results, { feed = feed, ok = ok, body_or_err = body_or_err })
				in_flight = in_flight - 1
				remaining = remaining - 1
				if remaining == 0 then
					on_done(results)
				else
					start_next()
				end
			end)
		end
	end

	start_next()
end

return M
