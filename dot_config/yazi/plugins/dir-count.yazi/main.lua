-- Non-recursive counts of folders and files in the current directory,
-- for yatline's status line. Registered as coloreds component "dir-count":
--   📂 42  📄 1337   (dirs blue, files green)
--
-- Deliberately NON-RECURSIVE: a single fs.read_dir of the cwd (one
-- getdents burst — milliseconds, no disk thrashing in big home dirs).
-- The recursive walk proved too heavy; if you ever want it back, push
-- subdirs onto a stack again (see git history).
--
-- Notes:
--   * symlinks are never followed (counted as files, no loops)
--   * hidden entries are included (matches show_hidden = true)
--   * unreadable root → ⏱

local state = ya.sync(function(st)
	return st
end)

local set_result = ya.sync(function(st, cwd, result)
	st.c_cache = st.c_cache or {}
	local tag = "cnt:" .. cwd
	if st.spin then
		st.spin[tag] = nil
	end

	-- This run is over: release the slot — but only if it is still OURS.
	-- entry() cannot do this itself: its `st` is a throwaway isolate table.
	if st.c_pending == cwd then
		st.c_pending = nil
	end

	local old = st.c_cache[cwd]
	if
		type(old) == "table"
		and type(result) == "table"
		and old[1] == result[1]
		and old[2] == result[2]
	then
		return -- value unchanged → no re-render
	end
	st.c_cache[cwd] = result
	ui.render()
end)

local get_cwd = ya.sync(function(_)
	return tostring(cx.active.current.cwd)
end)

local SPIN = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function spin_char(s, tag)
	local n = s.spin and s.spin[tag] or 0
	return SPIN[(n % #SPIN) + 1]
end

local DIRS_ICON = "📂"
local FILES_ICON = "📄"

local function setup(st, opts)
	opts = opts or {}
	if opts.dirs_icon then
		DIRS_ICON = opts.dirs_icon
	end
	if opts.files_icon then
		FILES_ICON = opts.files_icon
	end

	local function request(cwd)
		if st.c_pending == cwd then
			return false
		end
		st.c_pending = cwd
		ya.emit("plugin", { st._id, ya.quote(cwd, true) })
		return true
	end

	-- Content changed: force a recount even if one is in flight.
	local function refresh()
		st.c_pending = nil
		request(get_cwd())
	end
	ps.sub("delete", refresh)
	ps.sub("trash", refresh)
	ps.sub("move", refresh)

	-- Universal hook: yazi fires `load(tab, url, stage)` every time a folder
	-- (re)loads — covers paste/create, renames, and external changes caught
	-- by yazi's own folder watcher (there is no dedicated "paste" event).
	-- Filter to the current cwd so preview/parent loads don't spam us.
	-- Entering a dir fires cd + a burst of load stages. Suppressing that
	-- burst outright (as dir-size does) is WRONG here: dir-size protects an
	-- expensive walk and has TTL/persistence to fall back on, while a recount
	-- is one read_dir — and a stale count sitting next to the file list is
	-- immediately visible. So: swallow the burst, but schedule exactly ONE
	-- recount per entry. The cached value keeps rendering meanwhile (no
	-- spinner flicker), and an externally changed dir is picked up on return.
	ps.sub("cd", function()
		local cwd = get_cwd()
		st.cd_url, st.cd_at = cwd, os.time()
		st.c_pending = nil
		request(cwd)
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
		Yatline.coloreds.get["dir-count"] = function()
			local current_cwd = tostring(cx.active.current.cwd)
			local tag = "cnt:" .. current_cwd
			local s = state()
			local cached = s.c_cache and s.c_cache[current_cwd]

			if cached == nil and st.c_pending ~= current_cwd then
				request(current_cwd)
			end

			if cached == nil then
				return { { DIRS_ICON .. " " .. spin_char(s, tag), "brightblack" } }
			elseif cached == false then
				return { { DIRS_ICON .. " ⏱", "brightblack" } } -- root unreadable
			end
			return {
				{ string.format("%s %d", DIRS_ICON, cached[1]), "blue" },
				{ string.format("  %s %d", FILES_ICON, cached[2]), "green" },
			}
		end
	end
end

local function entry(_st, job)
	local cwd = job.args and job.args[1]
	if type(cwd) ~= "string" or cwd == "" then
		cwd = get_cwd() -- defensive: never trust the arg protocol blindly
	end

	-- false = failed/unreadable, {dirs, files} = counts
	local result = false
	pcall(function()
		local files = fs.read_dir(Url(cwd), {})
		if type(files) ~= "table" then
			return -- root unreadable → ⏱
		end

		local n_dirs, n_files = 0, 0
		for _, f in ipairs(files) do
			local base = tostring(f.url):match("[^/]+$")
			if base ~= "." and base ~= ".." then
				if f.cha and f.cha.is_dir then
					n_dirs = n_dirs + 1
				else
					n_files = n_files + 1
				end
			end
		end
		result = { n_dirs, n_files }
	end)

	-- set_result also releases c_pending on the real state — the isolate
	-- table writes in entry() would be silently discarded
	set_result(cwd, result)
end

return { setup = setup, entry = entry }
