-- Total recursive size of the SELECTED files, for yatline's extra line.
-- Registered as yatline coloreds component "sel-size" (nil → hidden when
-- nothing is selected).
--
-- Standalone sibling of dir-size.yazi: entry() takes NO arguments — it
-- reads the current selection itself (no arg protocol through ya.emit).
-- Uses the native fs.calc_size walker (same engine as yazi's own
-- folder-size preview). While counting, the RUNNING TOTAL streams
-- (numbers tick up, ~10 fps wall clock) with a braille spinner prefix;
-- plain braille until the first bytes arrive.
--
-- Anti-jitter:
--   * selection key (sorted paths, \x01-joined) → per-key cache
--   * `sel_pending` coalesces duplicate runs
--   * entry always computes the selection CURRENT at its run time →
--     visual-select spam only ever walks the final set (+ cache-skip
--     for burst leftovers)
--   * ui.render() only when the visible value actually changed

local state = ya.sync(function(st)
	return st
end)

-- Selection key: sorted paths joined with \x01 (illegal in filenames).
local KEYSEP = "\x01"

local function selection_key(paths)
	local sorted = {}
	for i, p in ipairs(paths) do
		sorted[i] = p
	end
	table.sort(sorted)
	return table.concat(sorted, KEYSEP)
end

local get_current_sel = ya.sync(function(_)
	local sel = cx.active and cx.active.selected or {}
	if #sel == 0 then
		return nil
	end
	local paths = {}
	for _, url in pairs(sel) do
		paths[#paths + 1] = tostring(url)
	end
	return selection_key(paths)
end)

local set_sel_result = ya.sync(function(st, key, bytes, partial)
	st.sel_cache = st.sel_cache or {}
	st.sel_partial_done = st.sel_partial_done or {}
	local tag = "sel:" .. key
	if st.spin then
		st.spin[tag] = nil
	end
	if st.partial then
		st.partial[tag] = nil
	end

	-- This run is over: release the slot — but only if it is still OURS.
	-- entry() cannot do this itself: its `st` is a throwaway isolate table.
	if st.sel_pending == key then
		st.sel_pending, st.sel_pending_at = nil, nil
	end

	local old = st.sel_cache[key]
	local old_p = st.sel_partial_done[key]
	st.sel_cache[key] = bytes
	st.sel_partial_done[key] = partial or nil

	if old == bytes and old_p == st.sel_partial_done[key] then
		return -- value unchanged → no re-render
	end
	ui.render()
end)

-- Publish a running total (throttled by the caller to ~10 fps).
local set_progress = ya.sync(function(st, tag, bytes)
	st.partial = st.partial or {}
	st.partial[tag] = bytes
	st.spin = st.spin or {}
	st.spin[tag] = (st.spin[tag] or 0) + 1
	ui.render()
end)

-- Consult/release the REAL state from inside entry()'s isolate VM.
-- NOTE: must stay unconditional top-level ya.sync blocks — indices are
-- positional and must match between the app VM and the isolate.
local sel_should_walk = ya.sync(function(st, key)
	-- a newer selection was requested after this run was queued → let
	-- that run do the walking
	if st.sel_pending and st.sel_pending ~= key then
		return false
	end
	-- already computed (burst leftover from visual-select spam) → skip
	if st.sel_cache and st.sel_cache[key] ~= nil then
		return false
	end
	return true
end)

local sel_release = ya.sync(function(st, key)
	if key == nil or st.sel_pending == key then
		st.sel_pending, st.sel_pending_at = nil, nil
	end
	return true
end)

-- sel_max_ms lives on the real state (set by setup on the app thread);
-- entry()'s isolate table never saw it.
local sel_get_conf = ya.sync(function(st)
	return { sel_max_ms = st.sel_max_ms }
end)

local SPIN = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function spin_char(s, tag)
	local n = s.spin and s.spin[tag] or 0
	return SPIN[(n % #SPIN) + 1]
end

local ICON = "Σ"

local function setup(st, opts)
	opts = opts or {}
	if opts.icon then
		ICON = opts.icon
	end

	-- Walk time cap, same rationale as dir-size: capped walks end inside
	-- yazi's ~2s quit-confirm auto-resolve window (result marked "…").
	st.sel_max_ms = tonumber(opts.max_ms) or 1500

	if Yatline ~= nil then
		Yatline.coloreds.get["sel-size"] = function()
			local sel = cx.active and cx.active.selected or {}
			if #sel == 0 then
				return nil
			end

			local paths = {}
			for _, url in pairs(sel) do
				paths[#paths + 1] = tostring(url)
			end
			local key = selection_key(paths)
			local tag = "sel:" .. key

			local s = state()
			local cached = s.sel_cache and s.sel_cache[key]

			-- self-heal: a queued run was lost (e.g. the selection was cleared
			-- before it ran, so entry() bailed out) → sel_pending would pin
			-- this key forever and the spinner would never resolve
			if st.sel_pending == key and st.sel_pending_at and ya.time() - st.sel_pending_at > 15 then
				st.sel_pending, st.sel_pending_at = nil, nil
			end

			if cached == nil and st.sel_pending ~= key then
				st.sel_pending = key
				st.sel_pending_at = ya.time()
				ya.emit("plugin", { st._id })
			end

			if cached == nil then
				local partial = s.partial and s.partial[tag] or 0
				if partial > 0 then
					-- running total + spinner prefix ("still counting")
					return {
						{ spin_char(s, tag) .. " ", "brightblack" },
						{ ya.readable_size(partial), "yellow" },
					}
				end
				return { { ICON .. " " .. spin_char(s, tag), "brightblack" } }
			elseif cached == false then
				return { { ICON .. " ⏱", "brightblack" } } -- all paths failed
			end
			local suffix = (s.sel_partial_done and s.sel_partial_done[key]) and "…" or ""
			return { { string.format("%s %s%s", ICON, ya.readable_size(cached), suffix), "yellow" } }
		end
	end
end

local function entry(_st, _job)
	local key = get_current_sel()
	if not key then -- selection emptied while queued
		sel_release(nil) -- release the slot on the REAL state
		return
	end
	local tag = "sel:" .. key

	-- Consult the real state (this runs in a throwaway isolate VM where
	-- st.* would read nil): skip burst leftovers and superseded runs.
	if not sel_should_walk(key) then
		return
	end

	local total, ok_count, capped, errored = 0, 0, false, false
	local deadline = ya.time() + (tonumber(sel_get_conf().sel_max_ms) or 1500) / 1000
	for path in key:gmatch("[^\x01]+") do
		if capped then
			break -- budget spent, remaining paths skipped (partial result)
		end
		local ok = pcall(function()
			local last = ya.time() - 1 -- first recv streams immediately
			local it = fs.calc_size(Url(path))
			while true do
				local n, err = it:recv()
				if n == nil then
					if err ~= nil then
						-- I/O failure on THIS path → mark the sum partial, but do
						-- NOT spend the time budget: the other selected paths are
						-- still perfectly readable.
						errored = true
					end
					break
			end
				total = total + n
				-- stream the running total, ~10 fps wall clock
				local now = ya.time()
				if now - last >= 0.1 then
					last = now
					set_progress(tag, total)
				end
				if now > deadline then
					capped = true
					break
				end
			end
		end)
		if ok then
			ok_count = ok_count + 1
		end
	end

	-- false only when EVERY path failed; partial failures undercount.
	-- (set_sel_result also releases sel_pending on the real state — the
	-- isolate table writes here would be silently discarded)
	set_sel_result(key, ok_count > 0 and total or false, capped or errored)
end

return { setup = setup, entry = entry }
