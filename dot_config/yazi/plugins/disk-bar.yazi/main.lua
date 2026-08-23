-- Local fork of pakhromov/yatline-disk-usage, extended with:
--   * a rounded fill-bar (pill shape) — like the old fs-usage plugin
--   * canonical "Model:Role" disk names from the table passed to setup()
-- Not managed by `ya pkg` → survives `ya pkg upgrade`. Registered as yatline
-- coloreds component "disk-bar".
local BAR_WIDTH = 10

-- Rounded powerline caps, emitted as UTF-8 byte escapes so the exact
-- codepoints are written regardless of editor glyph substitution.
local CAP_L = "\238\130\182" -- U+E0B6  left round cap (round side faces left)
local CAP_R = "\238\130\180" -- U+E0B4  right round cap (round side faces right)

local state = ya.sync(function(st)
	return st
end)

local set_state = ya.sync(function(st, cwd, source, usage)
	st.cwd = cwd
	st.source = source
	st.usage = usage
	ui.render()
end)

local get_cwd = ya.sync(function(_)
	return tostring(cx.active.current.cwd)
end)

local NAMES = {} -- { models = {...}, roles = {...} }, filled by setup()

-- /dev/nvme1n1p5 -> nvme1n1 ; /dev/sda1 -> sda ; non-/dev/ -> nil
local function physical_disk(source)
	local dev = source:match("^/dev/(.+)$")
	if not dev then
		return nil
	end
	return dev:match("^(nvme%d+n%d+)p%d+$")
		or dev:match("^(nvme%d+n%d+)$")
		or dev:match("^(sd[a-z])%d*$")
		or dev:match("^(hd[a-z])%d*$")
		or dev:match("^(vd[a-z])%d*$")
		or dev:match("^(mmcblk%d+)p%d+$")
		or dev:match("^(.-)p%d+$")
		or dev
end

local function canonical(source)
	if not source or source == "" then
		return "?"
	end
	-- sshfs source looks like `user@host:/path` — strip the `:/path` part
	local key = source:match("^([^:]+)") or source

	local models = NAMES.models or {}
	local roles = NAMES.roles or {}
	local icons = NAMES.icons or {}

	local role = roles[source] or roles[key]
	local model
	local pd = physical_disk(source)
	if pd then
		model = models[pd]
	end

	local disk_icon = pd and (icons.disks or {})[pd] or ""
	local role_icon = role and (icons.roles or {})[role] or ""

	if model and role and role ~= "" then
		return string.format("%s %s : %s %s", disk_icon, model, role_icon, role)
	end
	if role and role ~= "" then
		if role_icon ~= "" then
			return string.format("%s %s", role_icon, role)
		end
		return role
	end
	if model then
		if disk_icon ~= "" then
			return string.format("%s %s", disk_icon, model)
		end
		return model
	end
	return source:gsub("^/dev/", "")
end

-- Rounded pill bar: CAP_L on the left, CAP_R on the right, filled blocks in
-- between. Caps replace the first/last body cell, so total width = BAR_WIDTH.
local function bar_segments(usage, fill_color, empty_color)
	local filled = math.floor((usage / 100) * BAR_WIDTH + 0.5)
	if filled > BAR_WIDTH then
		filled = BAR_WIDTH
	end
	if filled < 0 then
		filled = 0
	end

	local segs = {}
	local cur_color, cur_text = nil, ""
	local function flush()
		if cur_text ~= "" then
			segs[#segs + 1] = { cur_text, cur_color }
		end
		cur_text = ""
	end
	for i = 1, BAR_WIDTH do
		local is_filled = i <= filled
		local ch
		if i == 1 then
			ch = CAP_L
		elseif i == BAR_WIDTH then
			ch = CAP_R
		else
			ch = is_filled and "█" or "░"
		end
		local color = is_filled and fill_color or empty_color
		if color ~= cur_color then
			flush()
			cur_color = color
		end
		cur_text = cur_text .. ch
	end
	flush()
	return segs
end

local function setup(st, opts)
	opts = opts or {}
	NAMES = opts.names or {}

	local function refresh()
		local cwd = get_cwd()
		ya.emit("plugin", { st._id, ya.quote(cwd, true) })
	end

	ps.sub("cd", refresh)
	ps.sub("tab", refresh)
	ps.sub("delete", refresh)
	ps.sub("trash", refresh)
	ps.sub("move", refresh)
	ps.sub("@yank", refresh)

	if Yatline ~= nil then
		Yatline.coloreds.get["disk-bar"] = function()
			local current_cwd = tostring(cx.active.current.cwd)
			local s = state()

			if s.cwd ~= current_cwd then
				ya.emit("plugin", { st._id, ya.quote(current_cwd, true) })
			end

			if not s.usage then
				return {}
			end

			local usage = s.usage
			local color
			if usage > 85 then
				color = "red"
			elseif usage >= 65 then
				color = "yellow"
			else
				color = "green"
			end

			-- label · rounded pill bar · percent
			local out = {
				{ string.format("%s ", canonical(s.source)), color },
			}
			for _, seg in ipairs(bar_segments(usage, color, "brightblack")) do
				out[#out + 1] = seg
			end
			out[#out + 1] = { string.format(" %d%%", usage), color }
			return out
		end
	end
end

local function entry(st, job)
	local cwd = job.args[1]

	-- findmnt handles Btrfs subvolumes correctly (df returns "-" for them)
	local output = Command("timeout"):arg("1"):arg("findmnt"):arg("-n"):arg("-o"):arg("SOURCE,USE%"):arg("-T"):arg(cwd):output()

	if not output or not output.status.success then
		set_state(cwd, "", nil)
		return
	end

	local source, usage = output.stdout:match("^(%S+)%s+(%d+)%%")
	if not source then
		set_state(cwd, "", nil)
		return
	end

	-- Strip Btrfs subvolume suffix, e.g. /dev/nvme1n1p5[/@home] -> /dev/nvme1n1p5
	source = source:gsub("%[.*%]", "")
	usage = tonumber(usage)

	if source == st.source and usage == st.usage and cwd == st.cwd then
		return
	end

	set_state(cwd, source, usage)
end

return { setup = setup, entry = entry }
