-- Recursive size of the current directory for yatline's extra line.
-- Registered as yatline coloreds component "dir-size".
--
-- v4: native fs.calc_size walker (the same engine yazi's own folder-size
-- preview uses — fast, parallel). While counting, the RUNNING TOTAL is
-- streamed (numbers tick up, ~10 fps on the wall clock via ya.time),
-- with a small braille spinner prefix as the "still counting" marker;
-- plain braille only until the first bytes arrive.
--
-- Anti-jitter:
--   * per-cwd cache — revisited dirs render instantly
--   * `pending` coalesces duplicate runs
--   * stale completions only update the cache of THEIR dir
--   * ui.render() fires only when the visible value actually changed

local state = ya.sync(function(st)
	return st
end)

local set_result = ya.sync(function(st, cwd, bytes, partial)
	st.cache = st.cache or {}
	st.partial_done = st.partial_done or {}
	st.cache_ts = st.cache_ts or {}
	local tag = "dir:" .. cwd
	if st.spin then
		st.spin[tag] = nil
	end
	if st.partial then
		st.partial[tag] = nil
	end

	-- This run is over: release the slot — but only if it is still OURS
	-- (a newer request for another dir may have taken it over). entry()
	-- cannot do this itself: its `st` is a throwaway isolate table.
	if st.pending == cwd then
		st.pending, st.pending_at = nil, nil
	end

	-- Never downgrade a known-complete size to a truncated one: a capped
	-- walk of an already-measured dir knows strictly LESS than the cache.
	-- A forced refresh on a dir heavier than the cap would otherwise
	-- replace a good number with an "…" stub. A partial that EXCEEDS the
	-- old value is accepted: the dir demonstrably grew.
	local downgrade = partial == true
		and bytes ~= false
		and type(st.cache[cwd]) == "number"
		and not st.partial_done[cwd]
		and bytes <= st.cache[cwd]

	if not downgrade then
		local old = st.cache[cwd]
		local old_p = st.partial_done[cwd]
		st.cache[cwd] = bytes
		st.partial_done[cwd] = partial or nil
		st.cache_ts[cwd] = (partial ~= true and bytes ~= false) and os.time() or nil

		if old ~= bytes or old_p ~= st.partial_done[cwd] then
			ui.render()
		end
	else
		-- The old number is kept (it is strictly more informative than the
		-- stub), but it is no longer verified: flag it so the UI shows "…"
		-- and claim_persist stops snapshotting it to disk.
		if not st.partial_done[cwd] then
			st.partial_done[cwd] = true
			ui.render()
		end
	end

	-- A full result re-arms the retry budget for this dir.
	if partial ~= true and bytes ~= false then
		if st.retries then
			st.retries[cwd] = nil
		end
		return
	end

	-- One warm-cache retry for capped walks: the first pass heats the
	-- metadata cache, so an immediate second attempt often completes
	-- what the cap cut. After that the dir is "hopeless" for this
	-- session — revisits show the cached partial instantly instead of
	-- re-counting forever.
	if bytes ~= false and ((st.retries or {})[cwd] or 0) < 1 then
		st.retries = st.retries or {}
		st.retries[cwd] = (st.retries[cwd] or 0) + 1
		-- keep the retry visible to request() so a redraw cannot double-queue it
		st.pending, st.pending_at = cwd, ya.time()
		ya.emit("plugin", { st._id, ya.quote(cwd, true) })
	end
end)

-- Publish a running total (throttled by the caller to ~10 fps).
local set_progress = ya.sync(function(st, tag, bytes)
	st.partial = st.partial or {}
	st.partial[tag] = bytes
	st.spin = st.spin or {}
	st.spin[tag] = (st.spin[tag] or 0) + 1
	ui.render()
end)

local get_cwd = ya.sync(function(_)
	return tostring(cx.active.current.cwd)
end)

-- entry() runs in a THROWAWAY Lua VM (Runner::spawn → Lua::new()), where the
-- module table is freshly loaded and setup() never ran — `st.foo` reads nil
-- there. Everything setup() configured must be fetched through a sync block,
-- which executes on the app thread against the REAL plugin table.
-- NOTE: must stay an unconditional top-level ya.sync — block indices are
-- positional and must match between the app VM and the isolate.
local get_conf = ya.sync(function(st)
	return { max_ms = st.max_ms, persist_path = st.persist_path }
end)

local SPIN = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function spin_char(s, tag)
	local n = s.spin and s.spin[tag] or 0
	return SPIN[(n % #SPIN) + 1]
end

local ICON = "📁"

local function setup(st, opts)
	opts = opts or {}
	if opts.icon then
		ICON = opts.icon
	end

	-- Walk time cap: yazi's quit-confirm auto-resolves once ongoing tasks
	-- drain (it polls for ~2s). A capped walk always ends well inside that
	-- window, so quitting never blocks on us; the result is marked partial
	-- ("…"). Raise it if you don't mind occasionally confirming a quit.
	st.max_ms = tonumber(opts.max_ms) or 1500

	-- Persistent cache: FULL results survive restarts (revisit → instant,
	-- no re-walk; one uncapped walk per dir per TTL). Capped/failed walks
	-- are never saved; in-session events still force re-walks on changes.
	st.cache = st.cache or {}
	st.cache_ts = st.cache_ts or {}
	if opts.persist_path ~= false then
		local base = os.getenv("XDG_CACHE_HOME")
			or (os.getenv("HOME") and os.getenv("HOME") .. "/.cache")
		st.persist_path = opts.persist_path or (base and base .. "/yazi/dir-size-cache.lua")
		st.persist_ttl = (tonumber(opts.persist_ttl_days) or 30) * 86400

		-- The cache file is DATA, not a plugin: load it in text mode with an
		-- empty environment so a tampered file cannot execute anything.
		if st.persist_path then
			local ok, data = pcall(function()
				local chunk = loadfile(st.persist_path, "t", {})
				return chunk and chunk() or nil
			end)
			if ok and type(data) == "table" then
				local horizon = os.time() - st.persist_ttl
				for path, e in pairs(data) do
					if type(e) == "table" and type(e.size) == "number" and type(e.ts) == "number" and e.ts >= horizon then
						st.cache[path] = e.size
						st.cache_ts[path] = e.ts
					end
				end
			end
		end
	end

	-- Schedule a calc for `cwd` unless one is already in flight for it.
	local function request(cwd)
		if st.pending == cwd then
			return false
		end
		st.pending = cwd
		st.pending_at = ya.time()
		ya.emit("plugin", { st._id, ya.quote(cwd, true) })
		return true
	end

	-- Content of the current dir changed: force a re-walk even if one is
	-- already in flight — its result may predate the change (resetting
	-- pending re-queues a fresh run right after it).
	local function refresh()
		st.pending = nil
		st.pending_at = nil
		request(get_cwd())
	end
	ps.sub("delete", refresh)
	ps.sub("trash", refresh)
	ps.sub("move", refresh)

	-- Universal hook: yazi fires `load(tab, url, stage)` every time a folder
	-- (re)loads — covers paste/create, renames, and external changes caught
	-- by yazi's own folder watcher. Filtered to the current cwd.
		-- ENTERING a dir fires cd + a burst of load stages. That burst is NOT
	-- a content change: the getter already schedules the initial walk on
	-- cache miss, and on revisit the cache must win — otherwise every cd
	-- re-walks the dir from scratch (monster dirs would never rest).
	-- Loads arriving LATER (paste/create, external changes caught by the
	-- watcher) still force a re-walk.
	ps.sub("cd", function()
		st.cd_url = get_cwd()
		st.cd_at = os.time()
	end)

	ps.sub("load", function(a, b)
		local url
		if type(b) == "string" then
			url = b
		elseif b ~= nil then
			local s = tostring(b)
			if s:sub(1, 1) == "/" then
				url = s
			end
		elseif type(a) == "table" and a.url ~= nil then
			url = tostring(a.url)
		end
		if url ~= nil and url ~= get_cwd() then
			return -- another folder's load
		end
		if st.cd_url == get_cwd() and os.time() - (st.cd_at or 0) < 5 then
			return -- fresh cd: part of the entering load-burst, not a change
		end
		refresh()
	end)

	if Yatline ~= nil then
		Yatline.coloreds.get["dir-size"] = function()
			local current_cwd = tostring(cx.active.current.cwd)
			local tag = "dir:" .. current_cwd
			local s = state()
			local cached = s.cache and s.cache[current_cwd]

			-- self-heal: a scheduled run was lost and pending stuck → force
			if s.pending == current_cwd and s.pending_at and ya.time() - s.pending_at > 30 then
				st.pending, st.pending_at = nil, nil
				request(current_cwd)
			end

			if cached == nil and st.pending ~= current_cwd then
				request(current_cwd)
			end

			if cached == nil then
				local partial = s.partial and s.partial[tag] or 0
				if partial > 0 then
					-- running total + spinner prefix ("still counting")
					return {
						{ spin_char(s, tag) .. " ", "brightblack" },
						{ ya.readable_size(partial), "cyan" },
					}
				end
				return { { ICON .. " " .. spin_char(s, tag), "brightblack" } }
			elseif cached == false then
				return { { ICON .. " ⏱", "brightblack" } } -- calc failed
			end
			local suffix = (s.partial_done and s.partial_done[current_cwd]) and "…" or ""
			return { { string.format("%s %s%s", ICON, ya.readable_size(cached), suffix), "cyan" } }
		end
	end
end

-- Persist (throttled, best-effort): claim a write slot and snapshot the
-- full results; the async side serializes them to st.persist_path.
local claim_persist = ya.sync(function(st, now)
	if st.persist_path == nil or (st.last_save and now - st.last_save < 2) then
		return nil
	end
	st.last_save = now

	local snap = {}
	for path, v in pairs(st.cache or {}) do
		if type(v) == "number" and not (st.partial_done and st.partial_done[path]) then
			snap[path] = { size = v, ts = (st.cache_ts and st.cache_ts[path]) or os.time() }
		end
	end
	return snap
end)

local function persist(path)
	if path == nil then
		return
	end
	local ok, snap = pcall(claim_persist, ya.time())
	if not ok or type(snap) ~= "table" then
		return
	end
	pcall(function()
		-- tmp + rename: a kill mid-write must not leave a truncated file
		local tmp = path .. ".tmp"
		pcall(fs.create, "dir_all", Url(path:gsub("/[^/]*$", "")))
		local f = io.open(tmp, "w")
		if not f then
			return
		end
		f:write("return {\n")
		for p, e in pairs(snap) do
			f:write(string.format("\t[%q] = { size = %d, ts = %d },\n", p, e.size, e.ts))
		end
		f:write("}\n")
		f:close()
		os.rename(tmp, path) -- atomic on the same filesystem
	end)
end

local function entry(_st, job)
	-- entry() runs in a throwaway isolate VM: fetch everything setup()
	-- configured through sync blocks (which run against the real table)
	local conf = get_conf()

	local cwd = job.args and job.args[1]
	if type(cwd) ~= "string" or cwd == "" then
		cwd = get_cwd() -- defensive: never trust the arg protocol blindly
	end

	-- false = failed/unmeasurable, number = bytes
	local bytes = false
	local total = 0
	local capped = false
	local deadline = ya.time() + (tonumber(conf.max_ms) or 1500) / 1000
	local last = ya.time() - 1 -- first recv streams immediately
	pcall(function()
		local it = fs.calc_size(Url(cwd))
		while true do
			local n, err = it:recv()
			if n == nil then
				-- (nil, Error) = I/O failure mid-walk, plain nil = end of
			-- stream: without this the total silently under-reports and
			-- gets cached/persisted as COMPLETE
				if err ~= nil then
					capped = true
				end
				break
			end
			total = total + n
			-- stream the running total, ~10 fps on the WALL clock
			-- (os.clock would be CPU time — it barely advances on
			-- IO-bound walks)
			local now = ya.time()
			if now - last >= 0.1 then
				last = now
				set_progress("dir:" .. cwd, total)
			end
			-- time cap → partial result, walk ends inside the quit window
			if now > deadline then
				capped = true
				break
			end
		end
		bytes = total
	end)

	-- Cache the result even if cwd is no longer current — it stays valid
	-- for the next visit. Renders only when the value changed.
	-- (set_result also releases `pending` on the real state — the isolate
	-- table writes here would be silently discarded)
	set_result(cwd, bytes, capped)

	if not capped and bytes ~= false then
		persist(conf.persist_path)
	end
end

return { setup = setup, entry = entry }
