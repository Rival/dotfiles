-- Runtime smoke-test for yatline-extra + disk-bar + dir-size + sel-size.
-- Stubs yazi's Lua API, then executes the real plugin code paths.

-- LuaJIT polyfill: real yazi runs mlua where table.unpack exists
table.unpack = table.unpack or unpack

-- Generic chain object: any method call returns the object itself.
local function chain()
	local t = {}
	setmetatable(t, {
		__index = function(_, k)
			if k == "stdout" then return "x" end
			return function() return t end
		end,
	})
	return t
end

-- Counters for anti-jitter verification
local EMITS, RENDERS = 0, 0

-- Live rect of the current column (set by tests; nil → ratio fallback)
local CURRENT_RECT

-- ui namespace: every constructor returns a chain object
ui = setmetatable({
	area = function(_name)
		return CURRENT_RECT
	end,
	Pad = setmetatable({}, {
		__index = function(_, k)
			return function(n)
				return { [k] = n }
			end
		end,
	}),
	Span = function() return chain() end,
	Line = function() return chain() end,
	Text = function() return chain() end,
	Paragraph = function() return chain() end,
	Layout = setmetatable(
		{ VERTICAL = {}, HORIZONTAL = {} },
		{ __call = function() return chain() end }
	),
	Rect = { default = function() return chain() end },
	Constraint = { Length = function() return {} end, Fill = function() return {} end },
	Align = { RIGHT = {}, LEFT = {}, CENTER = {} },
	Wrap = { NO = {}, YES = {} },
	redraw = function() return {} end,
	truncate = function(s) return s end,
	render = function() RENDERS = RENDERS + 1 end,
}, {
	__index = function() return function() return chain() end end,
})

-- Shared plugin state (mimics yazi's per-plugin st table)
local YA_SHARED = { _id = "stub-plugin" } -- _id как это делает LOADER.load в проде

-- Fake monotonic wall clock for ya.time(): advances 0.06s per call,
-- so the 0.1s spinner gate passes every ~2nd check.
local TIME_FAKE = 0

ya = {
	sync = function(f)
		return function(...) return f(YA_SHARED, ...) end
	end,
	time = function()
		TIME_FAKE = TIME_FAKE + 0.06
		return TIME_FAKE
	end,
	emit = function(kind, args)
		-- как yazi-core/src/app/plugin.rs:24-26 — пустой plugin id это ошибка
		if kind == "plugin" and (args == nil or args[1] == nil or args[1] == "") then
			error('ya.emit("plugin"): plugin id cannot be empty')
		end
		EMITS = EMITS + 1
	end,
	notify = function() end,
	quote = function(s) return s end,
	readable_path = function(s) return s end,
	readable_size = function(n) return tostring(n) end,
	list_merge = function(a, b)
		local r = { table.unpack(a) }
		for _, v in ipairs(b) do
			r[#r + 1] = v
		end
		return r
	end,
	user_name = function() return "user" end,
	group_name = function() return "group" end,
}

-- ps stub: record subscriptions per kind (multiple plugins may subscribe)
local SUBS = {}
ps = {
	sub = function(kind, cb)
		SUBS[kind] = SUBS[kind] or {}
		table.insert(SUBS[kind], cb)
	end,
}
rt = {
	term = { light = false },
	mgr = { ratio = { parent = 2, current = 7, preview = 5, all = 14 } },
}

Command = function(_name)
	local c = chain()
	getmetatable(c).__index = function(_, k)
		if k == "output" then
			return function() return { status = { success = true }, stdout = "" } end
		end
		return function() return c end
	end
	return c
end

Url = function(s) return s end

-- fs.* async API stub: each path yields 100 bytes then ends;
-- /many yields 1 byte 200 times (spinner animation test);
-- paths under /fail raise an error.
-- read_dir walks TREE (dir-count test): /tmp → 2 files + sub/, sub → 1 file.
local TREE = {
	["/tmp"] = {
		{ url = "/tmp/a.txt", cha = { is_dir = false } },
		{ url = "/tmp/b.txt", cha = { is_dir = false } },
		{ url = "/tmp/sub", cha = { is_dir = true } },
	},
	["/tmp/sub"] = {
		{ url = "/tmp/sub/c.txt", cha = { is_dir = false } },
	},
	["/cnt2"] = {
		{ url = "/cnt2/only.txt", cha = { is_dir = false } },
	},
}
fs = {
	calc_size = function(path)
		local p = tostring(path)
		if p:match("^/fail") then
			error("boom: " .. p)
		end
		if p == "/errmid" then
			-- I/O failure MID-walk: creation ok, first recv errors
			local done = false
			return {
				recv = function()
					if done then
						return nil
					end
					done = true
					return nil, "io error"
				end,
			}
		end
		if p == "/many" or p == "/many2" or p == "/many3" then
			local left = 200
			return {
				recv = function()
					if left <= 0 then
						return nil
					end
					left = left - 1
					return 1
				end,
			}
		end
		local done = false
		return {
			recv = function()
				if done then
					return nil
				end
				done = true
				return 100
			end,
		}
	end,
	read_dir = function(dir, _opts)
		local p = tostring(dir)
		if p:match("^/failcnt") then
			return nil, "boom"
		end
		return TREE[p] or {}
	end,
}

-- cx context (CWD_PATH is mutable for stale-completion tests)
local CWD_PATH = "/tmp"
local files = setmetatable({}, { __len = function() return 3 end })
local cwd = setmetatable({}, { __tostring = function() return CWD_PATH end })
cx = {
	active = {
		mode = {},
		current = { hovered = nil, cwd = cwd, files = files, cursor = 0 },
		selected = {}, -- mutable real table (paths as fake url strings)
		finder = nil,
	},
	tabs = setmetatable({ idx = 1, { name = "tab1", mode = {} }, { name = "tab2", mode = {} } }, {
		__len = function() return 2 end,
	}),
	yanked = setmetatable({}, { __len = function() return 0 end, is_cut = false }),
	tasks = { summary = { total = 0, success = 0, failed = 0 } },
}

-- Widget globals (plain tables, like yazi presets)
for _, w in ipairs({ "Header", "Status", "Tab", "Tabs", "Modal", "Root", "Backdrop", "Progress" }) do
	_G[w] = { new = function(_, area) return chain() or area end }
end

-- === 1. yatline-extra setup with the exact config from init.lua ===
local yatline_extra = dofile(os.getenv("HOME") .. "/.config/yazi/plugins/yatline-extra.yazi/main.lua")

yatline_extra.setup(nil, {
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },
	padding = { inner = 1, outer = 1 },
	style_a = { bg = "#0dcdcd", fg = "black", bg_mode = { normal = "#0dcdcd", select = "brightyellow", un_set = "brightred" } },
	style_b = { bg = "brightblack", fg = "brightwhite" },
	style_c = { bg = "black", fg = "brightwhite" },
	show_background = true,
	current_col_align = { extra = 1, extra_edge = 1, status = 1 },
	display_header_line = true,
	display_status_line = true,
	display_extra_line = true,
	component_positions = { "header", "extra1", "tab", "status" },
	header_line = {
		left = { section_a = { { type = "line", name = "tabs" } }, section_b = {}, section_c = {} },
		right = { section_a = {}, section_b = {}, section_c = { { type = "coloreds", custom = false, name = "disk-bar" } } },
	},
	status_line = {
		left = {
			section_a = { { type = "string", name = "tab_mode" } },
			section_b = {},
			section_c = { { type = "coloreds", name = "dir-count" } },
		},
		right = {
			section_a = { { type = "string", name = "cursor_position" } },
			section_b = {},
			section_c = { { type = "string", name = "cursor_percentage" }, { type = "coloreds", name = "permissions" } },
		},
	},
	extra_lines = {
		{
			left = { section_a = {}, section_b = {}, section_c = {
				{ type = "coloreds", name = "dir-size" },
				{ type = "string", name = "tab_path", params = { true, 60, 25 } },
				{ type = "coloreds", name = "count", params = { false, true } },
				{ type = "coloreds", name = "sel-size" },
			} },
			right = { section_a = {}, section_b = {}, section_c = {} },
		},
	},
})

print("yatline-extra: setup() OK")
assert(Yatline.config.display_extra_line == true, "display_extra_line not set")
assert(Yatline.config.current_col_align and Yatline.config.current_col_align.extra == 1, "current_col_align default missing")
assert(#Yatline.config.extra_lines == 1, "extra_lines not merged")
assert(#Yatline.config.extra_lines[1].left.section_c == 4, "expected 4 components on extra line")
assert(Yatline.config.extra_lines[1].left.section_c[4].name == "sel-size", "sel-size not on extra line")
print("config merge OK")

-- === 2. Root.layout + Root.build with stubbed self ===
local root_self = { _area = chain() }
Root.layout(root_self)
print("Root.layout() OK")
Root.build(root_self)
print("Root.build() OK, children = " .. tostring(#root_self._children))
assert(#root_self._children == 5, "expected 5 children: header, extra1, tab, status, modal")
assert(root_self._children[2]._index == 1, "children[2] should be ExtraLine idx 1")
print("ExtraLine widget placed correctly (top)")

-- === 3. disk-bar setup (component registered) ===
local disk_bar = dofile(os.getenv("HOME") .. "/.config/yazi/plugins/disk-bar.yazi/main.lua")
disk_bar.setup(YA_SHARED, { names = { models = {}, roles = {}, icons = {} } })
print("disk-bar: setup() OK")
local EMITS_BASE = EMITS

-- === 4. dir-size (native fs.calc_size, spinner, cache) ===
local DS_ST = YA_SHARED
local PERSIST_TEST = "/tmp/yazi-ds-cache-test.lua"
os.remove(PERSIST_TEST)

-- yazi runs entry() in a FRESH isolated Lua VM (Runner::spawn → Lua::new()),
-- where setup() never ran: st.* reads nil there. Model that: every entry()
-- call gets a throwaway module table, while ya.sync blocks keep hitting
-- the shared app state. (Sharing the table — as this suite used to — is
-- exactly what masked the B1/M1/M3/M4 bugs found in review.)
local PLUGINS = os.getenv("HOME") .. "/.config/yazi/plugins/"
local function entry_of(rel, args)
	local iso = dofile(PLUGINS .. rel)
	iso._id = rel:match("^([^/]+)%.yazi") -- как LOADER.load в проде
	iso.entry(iso, { args = args })
end

local dir_size = dofile(os.getenv("HOME") .. "/.config/yazi/plugins/dir-size.yazi/main.lua")
dir_size.setup(DS_ST, { persist_path = PERSIST_TEST })
print("dir-size: setup() OK")

-- 4a. first visit: spinner placeholder + exactly ONE request
local out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 ⠋", "expected spinner frame 1, got " .. tostring(out[1][1]))
assert(EMITS - EMITS_BASE == 1, "first visit should emit exactly 1 calc")
-- 4b. redraws while calc is in flight: pending coalesces
out = Yatline.coloreds.get["dir-size"]()
out = Yatline.coloreds.get["dir-size"]()
out = Yatline.coloreds.get["dir-size"]()
assert(EMITS - EMITS_BASE == 1, "pending must coalesce duplicate requests")
print("pending coalescing OK (3 extra renders → still 1 calc)")

-- 4c. calc completes → value shown, render fired once
entry_of("dir-size.yazi/main.lua", { "/tmp" })
assert(RENDERS == 2, "stream frame + final value = 2 renders, got " .. RENDERS)
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "expected size, got " .. tostring(out[1][1]))
assert(EMITS - EMITS_BASE == 1, "cache hit must not re-emit")
assert(YA_SHARED.pending == nil and YA_SHARED.pending_at == nil,
	"completed walk must release pending on the REAL state")
print("first measurement OK: 📁 100, pending released")

-- 4d. duplicate completion with same value → only its stream frame,
-- the FINAL value itself must not re-render (no jitter)
entry_of("dir-size.yazi/main.lua", { "/tmp" })
assert(RENDERS == 3, "duplicate's stream frame ok, final must not re-render, got " .. RENDERS)
print("duplicate completion OK (no jitter render of final value)")

-- 4e. stale completion (another dir) must not touch current display
entry_of("dir-size.yazi/main.lua", { "/other" })
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "stale completion must not flip current display")
print("stale completion OK (display stable)")

-- 4f. revisit via cache: instant, no new emit
CWD_PATH = "/other"
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "cached /other expected")
assert(EMITS - EMITS_BASE == 1, "revisit should use cache")
CWD_PATH = "/tmp"
print("per-cwd cache OK (revisit instant)")

-- 4g. failure path (fs.calc_size raises) → ⏱, no retry loop
CWD_PATH = "/fail"
out = Yatline.coloreds.get["dir-size"]() -- requests + placeholder
assert(EMITS - EMITS_BASE == 2, "failed dir should be requested once")
entry_of("dir-size.yazi/main.lua", { "/fail" })
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 ⏱", "expected clock icon, got " .. tostring(out[1][1]))
assert(EMITS - EMITS_BASE == 2, "cached failure must not retry (no loop)")
CWD_PATH = "/tmp"
print("failure path OK (⏱, no retry loop)")

-- 4h. spinner: seeded frame renders; cleared after completion
YA_SHARED.spin = { ["dir:/spin"] = 3 } -- frame index (3%10)+1 = 4 → ⠸
CWD_PATH = "/spin"
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 ⠸", "expected spinner frame 4, got " .. tostring(out[1][1]))
entry_of("dir-size.yazi/main.lua", { "/spin" })
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "expected value after spin, got " .. tostring(out[1][1]))
assert(YA_SHARED.spin["dir:/spin"] == nil, "spin frame must be cleared on completion")
CWD_PATH = "/tmp"
print("braille spinner OK (frame renders, cleared after)")

-- 4i. spinner animates on the WALL clock (ya.time), decoupled from files:
-- 200 yields with the fake clock (+0.06/call) → a tick every ~2nd recv
local R_BEFORE = RENDERS
CWD_PATH = "/many"
YA_SHARED.max_ms = 60000 -- don't cap this walk
out = Yatline.coloreds.get["dir-size"]() -- request + placeholder
entry_of("dir-size.yazi/main.lua", { "/many" })
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 200", "expected /many total, got " .. tostring(out[1][1]))
assert(RENDERS - R_BEFORE >= 5, "progress should stream, got " .. (RENDERS - R_BEFORE) .. " renders")
assert(YA_SHARED.partial["dir:/many"] == nil, "partial must be cleared on completion")
assert(YA_SHARED.partial_done["/many"] == nil, "full walk must not be marked partial")
CWD_PATH = "/tmp"
YA_SHARED.max_ms = 1500 -- restore default
print("streaming walker OK (" .. (RENDERS - R_BEFORE) .. " renders for 200 yields, ~10fps)")

-- 4j. running total display: partial + spin seeded → spinner prefix + number
YA_SHARED.spin = { ["dir:/run"] = 2 } -- frame (2%10)+1 = 3 → ⠹
YA_SHARED.partial = { ["dir:/run"] = 1234567890 }
CWD_PATH = "/run"
out = Yatline.coloreds.get["dir-size"]()
assert(type(out) == "table" and #out == 2, "expected two spans")
assert(out[1][1] == "⠹ " and out[1][2] == "brightblack", "spinner prefix, got " .. tostring(out[1][1]))
assert(out[2][1] == "1234567890" and out[2][2] == "cyan", "running total, got " .. tostring(out[2][1]))
CWD_PATH = "/tmp"
print("running total OK (⠹ 1234567890)")

-- 4k. TIME CAP + WARM RETRY: a capped walk is partial ("…"), schedules
-- exactly ONE immediate retry (the first pass heats the metadata cache,
-- the second often completes); a full result re-arms the budget
CWD_PATH = "/many2"
YA_SHARED.max_ms = 300 -- ~6 stub-clock iterations
out = Yatline.coloreds.get["dir-size"]() -- request + placeholder
local EMITS_K = EMITS
entry_of("dir-size.yazi/main.lua", { "/many2" }) -- capped → chains one retry
assert(EMITS - EMITS_K == 1, "capped completion must chain ONE retry, got " .. (EMITS - EMITS_K))
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1]:match("…$"), "capped result must be partial, got " .. tostring(out[1][1]))
assert(YA_SHARED.partial_done["/many2"] == true, "partial_done flag set")
local EMITS_K2 = EMITS
out = Yatline.coloreds.get["dir-size"]()
assert(EMITS == EMITS_K2, "cached partial getter must not re-emit")
-- the warm retry completes: raise the cap and re-run
YA_SHARED.max_ms = 60000
entry_of("dir-size.yazi/main.lua", { "/many2" })
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 200", "retry completed the full walk, got " .. tostring(out[1][1]))
assert(YA_SHARED.partial_done["/many2"] == nil, "full result clears the partial flag")
assert((YA_SHARED.retries or {})["/many2"] == nil, "full result re-arms the retry budget")
assert(YA_SHARED.pending == nil, "full completion releases pending")
CWD_PATH = "/tmp"
print("time cap + warm retry OK (partial → chained full: 📁 200)")

-- 4k2. HOPELESS dirs: after the retry also caps, stop trying —
-- revisits show the cached partial instantly (no recount forever)
YA_SHARED.max_ms = 300
CWD_PATH = "/many3"
out = Yatline.coloreds.get["dir-size"]() -- request
local EMITS_3 = EMITS
entry_of("dir-size.yazi/main.lua", { "/many3" }) -- first cap → chains (+1)
assert(EMITS - EMITS_3 == 1, "first cap chains one retry")
entry_of("dir-size.yazi/main.lua", { "/many3" }) -- second cap → silent
assert(EMITS - EMITS_3 == 1, "hopeless dir must not chain again")
local EMITS_3b = EMITS
CWD_PATH = "/tmp"
CWD_PATH = "/many3" -- revisit
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1]:match("…$") and EMITS == EMITS_3b, "revisit: cached partial, no recount")
CWD_PATH = "/tmp"
YA_SHARED.max_ms = 1500 -- restore default
print("hopeless dirs OK (one retry, then cached partial on revisit)")

-- 4k3. NO-DOWNGRADE (P3): a capped walk must never clobber a known-full
-- size (the "one move event ruins the cache" bug)
YA_SHARED.cache["/many"] = 999999999 -- a previously measured FULL value
YA_SHARED.partial_done["/many"] = nil
YA_SHARED.retries["/many"] = nil
CWD_PATH = "/many"
for _, cb in ipairs(SUBS["move"] or {}) do
	cb({ urls = {} }) -- forces a re-walk
end
YA_SHARED.max_ms = 300 -- the re-walk caps far below the old full value
entry_of("dir-size.yazi/main.lua", { "/many" })
assert(YA_SHARED.cache["/many"] == 999999999, "capped walk must not clobber a full result")
assert(YA_SHARED.partial_done["/many"] == true, "kept value must be honestly flagged (P12)")
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1]:match("999999999…"), "display: full value + '…' marker, got " .. tostring(out[1][1]))
CWD_PATH = "/tmp"
YA_SHARED.max_ms = 1500 -- restore default
print("no-downgrade OK (capped re-walk keeps the full value)")

-- 4k4. CONFIG REACHES entry() (P1): max_ms from setup must survive the
-- isolate boundary — default 1500 would cap this walk, 60000 completes it
YA_SHARED.cache["/many"] = nil
YA_SHARED.partial_done["/many"] = nil
YA_SHARED.retries["/many"] = nil
YA_SHARED.max_ms = 60000
CWD_PATH = "/many"
out = Yatline.coloreds.get["dir-size"]() -- request
entry_of("dir-size.yazi/main.lua", { "/many" })
assert(YA_SHARED.partial_done["/many"] == nil,
	"configured max_ms must reach entry() through get_conf")
assert(YA_SHARED.cache["/many"] == 200, "full walk under the configured cap")
CWD_PATH = "/tmp"
YA_SHARED.max_ms = 1500
print("config-through-sync OK (max_ms=60000 reached the isolate entry)")

-- 4l. PERSISTENCE: full completions hit the disk, capped ones never do,
-- and back-to-back writes are throttled
local disk = dofile(PERSIST_TEST)
assert(disk["/tmp"] and disk["/tmp"].size == 100, "full result persisted")
assert(disk["/many3"] == nil, "capped/hopeless result must not persist")
YA_SHARED.last_save = ya.time() -- force a fresh throttle window
local f = io.open(PERSIST_TEST, "a")
f:write("--marker\n")
f:close()
CWD_PATH = "/othertoo"
out = Yatline.coloreds.get["dir-size"]()
entry_of("dir-size.yazi/main.lua", { "/othertoo" }) -- full → persist attempted
local f2 = io.open(PERSIST_TEST, "r")
local tail = f2:read("*a")
f2:close()
assert(tail:find("--marker"), "second write within 2s must be throttled")
CWD_PATH = "/tmp"
print("persistence OK (full saved, capped skipped, writes throttled)")

-- 4m. cd + load-burst: ENTERING must not force a re-walk (the
-- "/mnt/Windows recounts on every entry" bug); a LATE load still does
CWD_PATH = "/many3"
local E0 = EMITS
for _, cb in ipairs(SUBS["cd"] or {}) do
	cb() -- disk-bar refreshes; dir-size just notes the cd
end
assert(EMITS - E0 == 1, "cd: only disk-bar emits, got " .. (EMITS - E0))
local E1 = EMITS
for _, cb in ipairs(SUBS["load"] or {}) do
	cb({ tab = 1, url = "/many3", stage = "Full" })
end
-- (dir-count's load handler is registered later in this suite; here
-- only dir-size's is live — it must stay silent after a fresh cd)
assert(EMITS - E1 == 0, "load burst after fresh cd: dir-size silent, got " .. (EMITS - E1))
YA_SHARED.cd_at = os.time() - 10 -- window expired
for _, cb in ipairs(SUBS["load"] or {}) do
	cb({ tab = 1, url = "/many3", stage = "Full" })
end
assert(EMITS - E1 == 1, "late load forces dir-size, got " .. (EMITS - E1))
CWD_PATH = "/tmp"
print("cd/load suppression OK (entering silent, late load forces)")

-- === 5. sel-size (standalone, argless entry) ===
local sel_size = dofile(os.getenv("HOME") .. "/.config/yazi/plugins/sel-size.yazi/main.lua")
sel_size.setup(DS_ST, {})
print("sel-size: setup() OK")

-- nothing selected → hidden
cx.active.selected = {}
local sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out == nil, "nothing selected must hide sel-size")
print("sel-size hidden when no selection OK")

-- two files → spinner placeholder, one emit, coalescing
local EMITS_SEL = EMITS
cx.active.selected = { "/tmp/a.txt", "/tmp/b.txt" }
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ ⠋", "expected spinner, got " .. tostring(sel_out[1][1]))
assert(EMITS - EMITS_SEL == 1, "new selection should emit once")
sel_out = Yatline.coloreds.get["sel-size"]() -- redraw while in flight
assert(EMITS - EMITS_SEL == 1, "sel pending must coalesce")

-- entry computes the CURRENT selection
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 200", "expected total, got " .. tostring(sel_out[1][1]))
assert(EMITS - EMITS_SEL == 1, "sel cache hit must not re-emit")
print("sel-size first calculation OK (Σ 200)")

-- burst leftover: duplicate entry skips via cache
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 200", "value must stay stable")
print("sel-size burst leftover OK (cache skip)")

-- selection grew mid-queue: entry walks the CURRENT final set
cx.active.selected = { "/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt" }
sel_out = Yatline.coloreds.get["sel-size"]()
assert(EMITS - EMITS_SEL == 2, "grown selection should emit once")
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 300", "expected Σ 300, got " .. tostring(sel_out[1][1]))
print("sel-size visual-select growth OK (Σ 300)")

-- spinner seeded frame for a fresh selection key
cx.active.selected = { "/tmp/x.txt", "/tmp/y.txt" }
local key_xy = "/tmp/x.txt\1/tmp/y.txt"
YA_SHARED.spin = { ["sel:" .. key_xy] = 2 } -- frame (2%10)+1 = 3 → ⠹
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ ⠹", "expected spinner frame 3, got " .. tostring(sel_out[1][1]))
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 200", "expected value after spin, got " .. tostring(sel_out[1][1]))
assert(YA_SHARED.spin["sel:" .. key_xy] == nil, "sel spin must be cleared")
print("sel-size braille spinner OK")

-- sel running total display (partial seeded → spinner prefix + number)
cx.active.selected = { "/tmp/p.txt", "/tmp/q.txt" }
local key_pq = "/tmp/p.txt\1/tmp/q.txt"
YA_SHARED.spin = { ["sel:" .. key_pq] = 5 } -- frame (5%10)+1 = 6 → ⠴
YA_SHARED.partial = { ["sel:" .. key_pq] = 555000 }
sel_out = Yatline.coloreds.get["sel-size"]()
assert(type(sel_out) == "table" and #sel_out == 2, "expected two spans")
assert(sel_out[1][1] == "⠴ " and sel_out[1][2] == "brightblack", "spinner prefix, got " .. tostring(sel_out[1][1]))
assert(sel_out[2][1] == "555000" and sel_out[2][2] == "yellow", "running total, got " .. tostring(sel_out[2][1]))
print("sel-size running total OK (⠴ 555000)")

-- failure: all paths raise → ⏱
cx.active.selected = { "/fail/f1", "/fail/f2" }
sel_out = Yatline.coloreds.get["sel-size"]() -- request + placeholder
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ ⏱", "expected clock, got " .. tostring(sel_out[1][1]))
print("sel-size failure path OK (Σ ⏱)")

-- R2/P11: I/O-ошибка на ОДНОМ пути не должна обрывать подсчёт остальных
-- (до P11 one error прерывал весь цикл по путям)
cx.active.selected = { "/errmid", "/tmp/a.txt" }
sel_out = Yatline.coloreds.get["sel-size"]()
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 100…", "other paths walked + partial mark, got " .. tostring(sel_out[1][1]))
cx.active.selected = {}
print("sel-size I/O error isolation OK (Σ 100…)")

-- selection emptied while queued → hidden, pending cleared
cx.active.selected = {}
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out == nil, "empty selection must hide")
print("sel-size empty selection OK")

-- TIME CAP: capped selection walk → "Σ …", no re-emit loop
cx.active.selected = { "/many2" }
YA_SHARED.sel_max_ms = 300
sel_out = Yatline.coloreds.get["sel-size"]()
local EMITS_SK = EMITS
entry_of("sel-size.yazi/main.lua", nil)
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1]:match("…$"), "capped sel must be partial, got " .. tostring(sel_out[1][1]))
assert(YA_SHARED.sel_partial_done and next(YA_SHARED.sel_partial_done) ~= nil, "sel partial flag")
assert(EMITS == EMITS_SK, "cached partial sel must not re-emit")
cx.active.selected = {}
print("sel-size time cap OK (" .. tostring(sel_out[1][1]) .. ")")

-- HANG FIX (P4): a run lost to an emptied selection must release the
-- slot on the REAL state — re-selecting the same set must re-emit.
-- (Before: sel_pending pinned the key forever → spinner, no walk ever.)
cx.active.selected = { "/tmp/h1.txt", "/tmp/h2.txt" } -- FRESH key (not cached yet)
sel_out = Yatline.coloreds.get["sel-size"]() -- request → sel_pending = key
assert(YA_SHARED.sel_pending ~= nil, "slot taken")
cx.active.selected = {} -- selection emptied while queued
entry_of("sel-size.yazi/main.lua", nil) -- bails out → must release
assert(YA_SHARED.sel_pending == nil, "bailed entry must release the slot")
cx.active.selected = { "/tmp/h1.txt", "/tmp/h2.txt" } -- same set again
local EMITS_H = EMITS
sel_out = Yatline.coloreds.get["sel-size"]()
assert(EMITS - EMITS_H == 1, "re-selected set must re-emit, got " .. (EMITS - EMITS_H))
entry_of("sel-size.yazi/main.lua", nil) -- completes
sel_out = Yatline.coloreds.get["sel-size"]()
assert(sel_out[1][1] == "Σ 200", "value after the rescued walk, got " .. tostring(sel_out[1][1]))
print("sel-size hang fix OK (lost run releases the slot)")

-- SELF-HEAL: aged sel_pending (a run lost without the bail-out path)
-- must self-heal on the next render
cx.active.selected = { "/tmp/x.txt" } -- fresh key → request
sel_out = Yatline.coloreds.get["sel-size"]()
assert(YA_SHARED.sel_pending ~= nil, "slot retaken")
YA_SHARED.sel_pending_at = -100 -- simulate a lost, aged run
local EMITS_SH = EMITS
sel_out = Yatline.coloreds.get["sel-size"]()
assert(EMITS - EMITS_SH == 1, "aged sel_pending must self-heal, got " .. (EMITS - EMITS_SH))
assert(YA_SHARED.sel_pending_at ~= -100, "timestamp refreshed")
cx.active.selected = {}
print("sel-size self-heal OK (aged pending re-emits)")
YA_SHARED.sel_max_ms = 1500 -- restore default

-- === 6. dir-count (recursive 📂/📄 counts for the status line) ===
local dir_count = dofile(os.getenv("HOME") .. "/.config/yazi/plugins/dir-count.yazi/main.lua")
dir_count.setup(DS_ST, {})
print("dir-count: setup() OK")

local EMITS_CNT = EMITS
-- first visit: icon + spinner placeholder, one emit, coalescing
local cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[1][1] == "📂 ⠋", "expected placeholder, got " .. tostring(cnt_out[1][1]))
assert(EMITS - EMITS_CNT == 1, "first visit should emit once")
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(EMITS - EMITS_CNT == 1, "pending must coalesce")

-- walk completes: /tmp is NON-RECURSIVE → 1 dir, 2 files
-- (sub/c.txt inside the subdir is NOT counted)
entry_of("dir-count.yazi/main.lua", { "/tmp" })
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[1][1] == "📂 1" and cnt_out[1][2] == "blue", "dirs span, got " .. tostring(cnt_out[1][1]))
assert(cnt_out[2][1] == "  📄 2" and cnt_out[2][2] == "green", "files span, got " .. tostring(cnt_out[2][1]))
assert(EMITS - EMITS_CNT == 1, "cache hit must not re-emit")
print("dir-count non-recursive OK (📂 1  📄 2)")

-- duplicate walk: streams running counts mid-way (event-driven refresh),
-- settles to the same final value without a final re-render flicker
entry_of("dir-count.yazi/main.lua", { "/tmp" })
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[1][1] == "📂 1" and cnt_out[2][1] == "  📄 2", "value must stay stable after duplicate walk")
print("dir-count duplicate walk OK (stable)")

-- another dir: 0 dirs, 1 file
CWD_PATH = "/cnt2"
cnt_out = Yatline.coloreds.get["dir-count"]()
entry_of("dir-count.yazi/main.lua", { "/cnt2" })
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[1][1] == "📂 0" and cnt_out[2][1] == "  📄 1", "cnt2 counts, got " .. tostring(cnt_out[1][1]))
CWD_PATH = "/tmp"
print("dir-count second dir OK (📂 0  📄 1)")

-- R1/P10: возврат в папку, изменённую снаружи — ровно ОДИН пересчёт на вход
-- (cd-хендлер сам заказывает пересчёт, load-вспышка подавлена окном)
TREE["/d"] = {
	{ url = "/d/a", cha = { is_dir = false } },
	{ url = "/d/b", cha = { is_dir = false } },
}
CWD_PATH = "/d"
out = Yatline.coloreds.get["dir-count"]() -- request
entry_of("dir-count.yazi/main.lua", { "/d" })
out = Yatline.coloreds.get["dir-count"]()
assert(out[2][1] == "  📄 2", "initial count, got " .. tostring(out[2][1]))
-- снаружи добавили ТРИ файла
for i = 1, 3 do
	TREE["/d"][#TREE["/d"] + 1] = { url = "/d/x" .. i, cha = { is_dir = false } }
end
local E10 = EMITS; for _, cb in ipairs(SUBS["cd"] or {}) do
	cb() -- disk-bar (+1) + dir-count recount (+1); dir-size молчит
end
for _, cb in ipairs(SUBS["load"] or {}) do
	cb({ tab = 1, url = "/d", stage = "Full" }) -- burst: оба окна глушат
end
assert(EMITS - E10 == 2, "cd: disk-bar + exactly ONE recount, got " .. (EMITS - E10))
entry_of("dir-count.yazi/main.lua", { "/d" })
out = Yatline.coloreds.get["dir-count"]()
assert(out[2][1] == "  📄 5", "external change picked up, got " .. tostring(out[2][1]))
CWD_PATH = "/tmp"
print("dir-count recount-on-entry OK (external change: 📄 5)")

-- root unreadable → ⏱, no retry loop
CWD_PATH = "/failcnt"
cnt_out = Yatline.coloreds.get["dir-count"]() -- emit + placeholder
entry_of("dir-count.yazi/main.lua", { "/failcnt" })
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[1][1] == "📂 ⏱", "expected clock, got " .. tostring(cnt_out[1][1]))
assert(EMITS - EMITS_CNT == 6, "tmp + cnt2 + /d + disk-bar-cd + /d recount + failcnt, got " .. (EMITS - EMITS_CNT))
CWD_PATH = "/tmp"
print("dir-count failure OK (⏱, no retry loop)")

-- load event regression: contents changed (paste/external) → counts refresh
local EMITS_LOAD = EMITS
TREE["/tmp"] = {
	{ url = "/tmp/a.txt", cha = { is_dir = false } },
	{ url = "/tmp/b.txt", cha = { is_dir = false } },
	{ url = "/tmp/d.txt", cha = { is_dir = false } },
	{ url = "/tmp/sub", cha = { is_dir = true } },
}
for _, cb in ipairs(SUBS["load"] or {}) do
	cb({ tab = 1, url = "/tmp", stage = "Full" })
end
-- both dir-size and dir-count requested a refresh (once each, coalesced)
assert(EMITS - EMITS_LOAD == 2, "load should refresh dir-size + dir-count once each, got " .. (EMITS - EMITS_LOAD))
entry_of("dir-size.yazi/main.lua", { "/tmp" }) -- same 100 → no visual change
entry_of("dir-count.yazi/main.lua", { "/tmp" }) -- {1,3} ≠ {1,2} → update
cnt_out = Yatline.coloreds.get["dir-count"]()
assert(cnt_out[2][1] == "  📄 3", "counts must update after load, got " .. tostring(cnt_out[2][1]))
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "dir-size stays stable")
print("load hook OK (📂 1  📄 3 after change)")

-- filter: load of an unrelated folder must not trigger anything
local EMITS_NOPE = EMITS
for _, cb in ipairs(SUBS["load"] or {}) do
	cb({ tab = 1, url = "/elsewhere", stage = "Full" })
end
assert(EMITS == EMITS_NOPE, "unrelated load must not refresh")
print("load filter OK (unrelated folder ignored)")

-- trash during an IN-FLIGHT walk: refresh must force a re-request
local EMITS_F = EMITS
CWD_PATH = "/force"
out = Yatline.coloreds.get["dir-size"]() -- request → pending set
assert(EMITS - EMITS_F == 1, "initial request")
for _, cb in ipairs(SUBS["trash"] or {}) do
	cb() -- fires while the walk is "in flight"
end
-- dir-size (forced) + dir-count (forced) + disk-bar = 3 more
assert(EMITS - EMITS_F == 4, "forced refresh must re-emit despite pending, got " .. (EMITS - EMITS_F))
entry_of("dir-size.yazi/main.lua", { "/force" }) -- completes with fresh data
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "value after forced refresh")
print("forced refresh on trash OK (re-emit despite pending)")

-- entry args fallback: missing/corrupt arg → use current cwd
CWD_PATH = "/tmp"
entry_of("dir-size.yazi/main.lua", nil) -- no args at all
entry_of("dir-count.yazi/main.lua", nil)
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "args fallback must not break dir-size")
print("entry args fallback OK")

-- stuck pending self-heal (a scheduled run was lost)
local EMITS_H = EMITS
YA_SHARED.pending = "/tmp" -- stuck on current cwd
YA_SHARED.pending_at = -100 -- very old
out = Yatline.coloreds.get["dir-size"]()
assert(EMITS - EMITS_H == 1, "self-heal must re-request, got " .. (EMITS - EMITS_H))
entry_of("dir-size.yazi/main.lua", { "/tmp" }) -- completes, clears pending
assert(YA_SHARED.pending == nil and YA_SHARED.pending_at == nil, "pending cleared after heal run")
out = Yatline.coloreds.get["dir-size"]()
assert(out[1][1] == "📁 100", "stable after heal")
print("stuck pending self-heal OK")

-- === 7. ExtraLine:redraw() + current-column alignment ===
local PAD_AREAS = {}
local function fake_area(x, y, w, h)
	return {
		x = x, y = y, w = w, h = h,
		pad = function(self, p)
			local l = (p and p.left) or 0
			local r = (p and p.right) or 0
			PAD_AREAS[#PAD_AREAS + 1] = { left = p and p.left, right = p and p.right, x = self.x }
			return fake_area(self.x + l, self.y, math.max(self.w - l - r, 1), self.h)
		end,
	}
end

-- live rect: current column starts at x=15, nudge 1 → left pad 16
CURRENT_RECT = { x = 15, y = 2, w = 70, h = 30 }
root_self._children[2]._area = fake_area(0, 1, 100, 1)
local r1 = root_self._children[2]:redraw()
-- extra_edge=1: size clipped at the edge (right pad 85), rest at column (left pad 16)
assert(#PAD_AREAS == 2, "extra split should pad twice, got " .. #PAD_AREAS)
assert(PAD_AREAS[1].right == 85, "edge group clipped (right pad 85), got " .. tostring(PAD_AREAS[1].right))
assert(PAD_AREAS[2].left == 16, "column group aligned (left pad 16), got " .. tostring(PAD_AREAS[2].left))
assert(#r1 == 3, "edge + column + right elements, got " .. #r1)
print("ExtraLine redraw OK, split align OK (size at edge, rest at column)")

-- ratio fallback: ui.area unavailable → floor(100*2/14 + 0.5) + 1 = 15
CURRENT_RECT = nil
PAD_AREAS = {}
root_self._children[2]:redraw()
assert(#PAD_AREAS == 2 and PAD_AREAS[1].right == 86 and PAD_AREAS[2].left == 15, "ratio fallback pads")
print("current-col align fallback OK (ratio math: pad 15)")

-- status SPLIT render: section_a (mode) clipped at the edge, b+c at column
CURRENT_RECT = { x = 15, y = 2, w = 70, h = 30 }
PAD_AREAS = {}
local status_self = {
	_area = fake_area(0, 10, 100, 1),
	LEFT = 0,
	RIGHT = 1,
	children_redraw = function(_, _side)
		return ui.Line({})
	end,
}
local status_els = Status.redraw(status_self)
assert(#PAD_AREAS == 2, "status split should pad twice, got " .. #PAD_AREAS)
assert(PAD_AREAS[1].right == 85, "section_a clipped (right pad 85), got " .. tostring(PAD_AREAS[1].right))
assert(PAD_AREAS[2].left == 16, "b+c aligned to column (left pad 16), got " .. tostring(PAD_AREAS[2].left))
assert(#status_els == 3, "a + bc + right elements, got " .. #status_els)
print("status split render OK (mode at edge, counts at column)")

local cnt = Yatline.coloreds.get["count"](Yatline.coloreds.get, false, true)
print("count (nothing selected, zero_check): " .. tostring(cnt))

local disk_out = Yatline.coloreds.get["disk-bar"]()
print("disk-bar component: " .. tostring(type(disk_out)))


-- === 9. persistence reload: sizes survive a "restart" ===
YA_SHARED.cache = nil
YA_SHARED.cache_ts = nil
YA_SHARED.partial_done = nil
YA_SHARED.pending = nil
local EMITS_R = EMITS
CWD_PATH = "/tmp"
dir_size.setup(DS_ST, { persist_path = PERSIST_TEST }) -- reload from disk
local out2 = Yatline.coloreds.get["dir-size"]()
assert(out2[1][1] == "📁 100", "persisted size restored, got " .. tostring(out2[1][1]))
assert(EMITS == EMITS_R, "restored cache must not re-emit")
print("persist reload OK (instant after restart)")

-- TTL: stale entries dropped on load, fresh kept
local TTL_TEST = "/tmp/yazi-ds-ttl-test.lua"
local tf = io.open(TTL_TEST, "w")
tf:write(string.format(
	"return { ['/stale'] = { size = 5, ts = %d }, ['/fresh'] = { size = 7, ts = %d } }",
	os.time() - 40 * 86400, os.time()
))
tf:close()
YA_SHARED.cache = nil
dir_size.setup(DS_ST, { persist_path = TTL_TEST })
CWD_PATH = "/stale"
local EMITS_T = EMITS
out2 = Yatline.coloreds.get["dir-size"]()
assert(EMITS - EMITS_T == 1, "stale entry must be re-walked")
entry_of("dir-size.yazi/main.lua", { "/stale" })
out2 = Yatline.coloreds.get["dir-size"]()
assert(out2[1][1] == "📁 100", "re-walked value, got " .. tostring(out2[1][1]))
CWD_PATH = "/fresh"
out2 = Yatline.coloreds.get["dir-size"]()
assert(out2[1][1] == "📁 7" and EMITS == EMITS_T + 1, "fresh entry kept, got " .. tostring(out2[1][1]))
print("persist TTL OK (stale dropped, fresh kept)")
os.remove(TTL_TEST)
os.remove(PERSIST_TEST)

-- === DiskTabs: имена дисков в табах ===
-- Правило: ≥ 2 таба на РАЗНЫХ дисках → каждому табу префикс "иконка+роль",
-- иначе — без префикса (как сейчас).
local DT = Yatline.disk_tabs
assert(DT, "Yatline.disk_tabs module missing")

local MOUNTS_FIXTURE = table.concat({
	"/dev/nvme1n1p5 / btrfs rw,subvol=@ 0 0",
	"/dev/nvme1n1p2 /mnt/Windows ntfs3 rw 0 0",
	"/dev/nvme0n1p2 /mnt/Crucial4TB btrfs rw 0 0",
	"/dev/sda1 /mnt/Downloads2TB ext4 rw 0 0",
	"Movies-Pool /mnt/Movies-Pool fuse.mergerfs rw 0 0",
	"regina@macmini1:/media /mnt/macmini fuse.sshfs rw 0 0",
	"tmpfs /tmp tmpfs rw 0 0", -- псевдо-FS: не диск, матчится в корень
}, "\n")

local DN = dofile(os.getenv("HOME") .. "/.config/yazi/disk-names.lua")

-- Парс: tmpfs/proc/sysfs и прочая псевдо-FS исключается
local mounts = DT.parse_mounts(MOUNTS_FIXTURE)
assert(#mounts == 6, "expected 6 real mounts (tmpfs excluded), got " .. #mounts)

-- Резолв: longest-prefix по маунтпоинтам
local function src(path) return DT.resolve(path, mounts, DN).source end
assert(src("/home/andrei/x") == "/dev/nvme1n1p5", "root subvol → nvme1n1p5")
assert(src("/mnt/Windows/System32") == "/dev/nvme1n1p2", "Windows partition")
assert(src("/mnt/Crucial4TB/a/b") == "/dev/nvme0n1p2", "Crucial partition")
assert(src("/mnt/Movies-Pool/films") == "Movies-Pool", "mergerfs pool source")
assert(src("/mnt/macmini/Downloads") == "regina@macmini1", "sshfs host key")
assert(src("/tmp/scratch") == "/dev/nvme1n1p5", "tmpfs не диск → корневой источник")
assert(DT.resolve("/нет/такого/пути", mounts, DN).source == "/dev/nvme1n1p5", "fallback — корень")

-- Метки: короткая форма "иконка роль"
local function label(path) return DT.resolve(path, mounts, DN).label end
assert(label("/mnt/Windows") == "🪟 Windows", "got " .. tostring(label("/mnt/Windows")))
assert(label("/") == "🐧 CachyOS", "got " .. tostring(label("/")))
assert(label("/mnt/Movies-Pool") == "🎬 Movies", "got " .. tostring(label("/mnt/Movies-Pool")))
assert(label("/mnt/macmini") == "🖥️ Mac mini", "got " .. tostring(label("/mnt/macmini")))
-- Без disk-names — фолбэк: имя источника без /dev/
local nb = DT.resolve("/mnt/Windows", mounts, {})
assert(nb.label == "nvme1n1p2", "no-names fallback, got " .. tostring(nb.label))

-- Решение: разные диски → массив меток; один диск / один таб → nil
local two = DT.prefixes({ "/home/a", "/mnt/Windows/w" }, mounts, DN)
assert(type(two) == "table" and two[1] == "🐧 CachyOS" and two[2] == "🪟 Windows", "two disks → labels")
assert(DT.prefixes({ "/home/a", "/etc/b" }, mounts, DN) == nil, "same disk → nil")
assert(DT.prefixes({ "/only/one" }, mounts, DN) == nil, "single tab → nil")
print("disk_tabs: parse/resolve/label/prefixes OK")

-- Интеграция: get:tabs рендерит префикс диска, ширина таба расширяется
DT.inject(MOUNTS_FIXTURE, DN)
local function fake_url(p)
	return setmetatable({}, { __tostring = function() return p end })
end
local captured = {}
local orig_truncate = ui.truncate
ui.truncate = function(s, o)
	captured[#captured + 1] = { text = s, max = o and o.max }
	return orig_truncate(s, o)
end
local orig_tabs = cx.tabs
cx.tabs = setmetatable({
	idx = 1,
	{ name = "home", mode = {}, current = { cwd = fake_url("/home/andrei") } },
	{ name = "Win", mode = {}, current = { cwd = fake_url("/mnt/Windows") } },
}, { __len = function() return 2 end })
Yatline.line.get:tabs("left")
assert(captured[1] and captured[1].text == "1 🐧 CachyOS/home", "tab1 text, got " .. tostring(captured[1] and captured[1].text))
assert(captured[2] and captured[2].text == "2 🪟 Windows/Win", "tab2 text, got " .. tostring(captured[2] and captured[2].text))
assert(captured[1].max == 20 + #"🐧 CachyOS" + 1, "width bumped by prefix, got " .. tostring(captured[1].max))
-- Один диск → рендер без префиксов (как сейчас)
captured = {}
cx.tabs = setmetatable({
	idx = 1,
	{ name = "a", mode = {}, current = { cwd = fake_url("/home/a") } },
	{ name = "b", mode = {}, current = { cwd = fake_url("/etc/b") } },
}, { __len = function() return 2 end })
Yatline.line.get:tabs("left")
assert(captured[1].text == "1 a", "same disk: no prefix, got " .. tostring(captured[1].text))
assert(captured[1].max == 20, "same disk: base width, got " .. tostring(captured[1].max))
ui.truncate = orig_truncate
cx.tabs = orig_tabs
print("disk_tabs: get:tabs render OK (prefix shown only for mixed disks)")

-- Симметричный pill: у ПЕРВОГО активного таба — своя левая капсула
-- (соседа слева нет, стык idx-1 не сработает)
local CAP_O, CAP_C = "\238\130\182", "\238\130\180" -- U+E0B6 / U+E0B4
local orig_span, orig_line = ui.Span, ui.Line
local orig_sep = Yatline.config.section_separator
Yatline.config.section_separator = { open = CAP_O, close = CAP_C }

local function rspan(text)
	local r = setmetatable({ txt = tostring(text) }, {
		__index = function(t, k)
			if k == "fg" or k == "bg" then
				return function(_, v)
					t[k] = v
					return t
				end
			end
			return function() return t end
		end,
	})
	return r
end
local function rline(args)
	return setmetatable({ kids = args or {} }, {
		__index = function(t, k)
			-- служебные ключи инспекции не перехватываем (иначе флаттен
			-- примет Line за лист): txt/kids должны быть "отсутствующими"
			if k == "txt" or k == "kids" then
				return nil
			end
			return function() return t end
		end,
	})
end
local function flatten(x, out)
	if type(x) == "string" then
		out[#out + 1] = { txt = x }
		return
	end
	if type(x) ~= "table" then
		return
	end
	if x.txt ~= nil then
		out[#out + 1] = x
	elseif x.kids then
		for _, k in ipairs(x.kids) do
			flatten(k, out)
		end
	end
end
local function pill_scenario(idx)
	ui.Span, ui.Line = rspan, rline
	cx.tabs = setmetatable({
		idx = idx,
		{ name = "home", mode = {}, current = { cwd = fake_url("/home/andrei") } },
		{ name = "Win", mode = {}, current = { cwd = fake_url("/mnt/Windows") } },
		{ name = "Crucial", mode = {}, current = { cwd = fake_url("/mnt/Crucial4TB") } },
	}, { __len = function() return 3 end })
	local out = Yatline.line.get:tabs("left")
	local flat = {}
	flatten(out, flat)
	ui.Span, ui.Line = orig_span, orig_line
	return flat
end

-- Сценарий А: активный #1 — флаттен НАЧИНАЕТСЯ с левой капсулы (fg=циан)
local fa = pill_scenario(1)
assert(fa[1].txt == CAP_O and fa[1].fg == "#0dcdcd", "active#1: нужна своя левая капсула E0B6, got '" .. tostring(fa[1].txt) .. "' fg=" .. tostring(fa[1].fg))
-- и текст активного таба идёт ПОСЛЕ капсулы (между ними — только паддинги)
local pos_text
for j, s in ipairs(fa) do
	if type(s.txt) == "string" and s.txt:sub(1, 2) == "1 " then
		pos_text = j
		break
	end
end
assert(pos_text and pos_text <= 4, "active#1: текст таба сразу за капсулой/паддингом, pos=" .. tostring(pos_text))
local has_right = false
for _, s in ipairs(fa) do
	if s.txt == CAP_C and s.fg == "#0dcdcd" then
		has_right = true
	end
end
assert(has_right, "active#1: правая капсула E0B4 на месте")

-- Сценарий Б: активный #2 — ОБЕ собственные яркие капсулы (fg=циан),
-- тёмная стыковая (bg=циан) больше не рисуется
local fb = pill_scenario(2)
local pos_text, own_left, own_right, dark_junction = nil, false, false, false
for j, s in ipairs(fb) do
	if not pos_text and type(s.txt) == "string" and s.txt:sub(1, 2) == "1 " then
		pos_text = j
	end
	if s.txt == CAP_O and s.fg == "#0dcdcd" then
		own_left = true
	end
	if s.txt == CAP_C and s.fg == "#0dcdcd" then
		own_right = true
	end
	if s.txt == CAP_C and s.bg == "#0dcdcd" then
		dark_junction = true
	end
end
assert(pos_text and pos_text <= 3, "active#2: текст таба №1 в начале, pos=" .. tostring(pos_text))
assert(own_left, "active#2: нужна своя левая капсула E0B6 fg=циан")
assert(own_right, "active#2: правая капсула E0B4 fg=циан на месте")
assert(not dark_junction, "active#2: тёмная стыковая капсула не должна рисоваться")

Yatline.config.section_separator = orig_sep
cx.tabs = orig_tabs
print("disk_tabs: симметричный pill OK (левая капсула первому активному)")

print("")
print("=== ALL RUNTIME TESTS PASSED ===")
