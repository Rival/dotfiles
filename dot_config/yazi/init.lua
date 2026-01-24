-- ~/.config/yazi/init.lua
-- require("custom-colors")
function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%b %d %H:%M", time)
	else
		time = os.date("%b %d  %Y", time)
	end

	local size = self._file:size()
	return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end

function Linemode:mtime_custom()
  local year = os.date("%Y")
  local time = (self._file.cha.modified or 0) --1

  if time > 0 and os.date("%Y", time) == year then
    time = os.date("%b %d %H:%M", time)
  else
    time = time and os.date("%b %d  %Y", time) or ""
  end

  -- local size = self._file:size()
  -- return ui.Line(string.format("%s", time))
  return string.format("%s haha", time)
  -- return time
end

require("full-border"):setup()
require("simple-status"):setup()

--require("git"):setup()

local pref_by_location = require("pref-by-location")
pref_by_location:setup({
  -- Disable this plugin completely.
  -- disabled = false -- true|false (Optional)

  -- Hide "enable" and "disable" notifications.
  -- no_notify = false -- true|false (Optional)

  -- Disable the fallback/default preference (values in `yazi.toml`).
  -- This mean if none of the saved or predifined perferences is matched,
  -- then it won't reset preference to default values in yazi.toml.
  -- For example, go from folder A to folder B (folder B matchs saved preference to show hidden files) -> show hidden.
  -- Then move back to folder A -> keep showing hidden files, because the folder A doesn't match any saved or predefined preference.
  -- disable_fallback_preference = false -- true|false|nil (Optional)

  -- You can backup/restore this file. But don't use same file in the different OS.
  -- save_path =  -- full path to save file (Optional)
  --       - Linux/MacOS: os.getenv("HOME") .. "/.config/yazi/pref-by-location"
  --       - Windows: os.getenv("APPDATA") .. "\\yazi\\config\\pref-by-location"

  -- This is predefined preferences.
  prefs = { -- (Optional)
    -- location: String | Lua pattern (Required)
    --   - Support literals full path, lua pattern (string.match pattern): https://www.lua.org/pil/20.2.html
    --     And don't put ($) sign at the end of the location. %$ is ok.
    --   - If you want to use special characters (such as . * ? + [ ] ( ) ^ $ %) in "location"
    --     you need to escape them with a percent sign (%) or use a helper funtion `pref_by_location.is_literal_string`
    --     Example: "/home/test/Hello (Lua) [world]" => { location = "/home/test/Hello %(Lua%) %[world%]", ....}
    --     or { location = pref_by_location.is_literal_string("/home/test/Hello (Lua) [world]"), .....}

    -- sort: {} (Optional) https://yazi-rs.github.io/docs/configuration/yazi#mgr.sort_by
    --   - extension: "none"|"mtime"|"btime"|"extension"|"alphabetical"|"natural"|"size"|"random", (Optional)
    --   - reverse: true|false (Optional)
    --   - dir_first: true|false (Optional)
    --   - translit: true|false (Optional)
    --   - sensitive: true|false (Optional)

    -- linemode: "none" |"size" |"btime" |"mtime" |"permissions" |"owner" (Optional) https://yazi-rs.github.io/docs/configuration/yazi#mgr.linemode
    --   - Custom linemode also work. See the example below

    -- show_hidden: true|false (Optional) https://yazi-rs.github.io/docs/configuration/yazi#mgr.show_hidden

    -- Some examples:
    -- Match any folder which has path start with "/mnt/remote/". Example: /mnt/remote/child/child2
    -- { location = "^/mnt/remote/.*", sort = { "extension", reverse = false, dir_first = true, sensitive = false} },
    -- Match any folder with name "Downloads"
    { location = ".*/Downloads", sort = { "btime", reverse = true, dir_first = true }, linemode = "btime" },
    -- Match exact folder with absolute path "/home/test/Videos".
    -- Use helper function `pref_by_location.is_literal_string` to prevent the case where the path contains special characters
    -- { location = pref_by_location.is_literal_string("/home/test/Videos"), sort = { "btime", reverse = true, dir_first = true }, linemode = "btime" },

    -- show_hidden for any folder with name "secret"
    -- {
    --  location = ".*/secret",
    --  sort = { "natural", reverse = false, dir_first = true },
    --  linemode = "size",
    --  show_hidden = true,
    -- },

    -- Custom linemode also work
    {
	    -- location = ".*/abc",
	    linemode = "size_and_mtime",
    },
    -- DO NOT ADD location = ".*". Which currently use your yazi.toml config as fallback.
    -- That mean if none of the saved perferences is matched, then it will use your config from yazi.toml.
    -- So change linemode, show_hidden, sort_xyz in yazi.toml instead.
  },
})

--git
-- signs
-- th.git.modified_sign
-- th.git.added_sign
-- th.git.untracked_sign
-- th.git.ignored_sign
-- th.git.deleted_sign
-- th.git.updated_sign

-- th.git = th.git or {}
-- th.git.modified_sign = "M"
-- th.git.deleted_sign = "D"
-- th.git.untracked_sign = "_"
-- th.git.ignored_sign = "_"

-- colors
-- th.git.modified
-- th.git.added
-- th.git.untracked
-- th.git.ignored
-- th.git.deleted
-- th.git.updated

-- th.git = th.git or {}
-- th.git.modified = ui.Style():fg("orange")
-- th.git.deleted = ui.Style():fg("red"):bold()
-- th.git.added = ui.Style():fg("green"):bold()

-- Get current time for comparison
local function get_current_time()
    return os.time()
end

-- Check if file was modified recently (within specified hours)
local function is_recently_modified(file, hours)
    return true
    -- if not file or not file.cha then
    --     return false
    -- end
    --
    -- local current_time = get_current_time()
    -- local modified_time = file.cha.modified
    --
    -- if not modified_time then
    --     return false
    -- end
    --
    -- local time_diff = current_time - modified_time
    -- local hours_diff = time_diff / 3600
    --
    -- return hours_diff <= hours
end

-- Override the Entity:highlight method
function Entity:highlight()
    local color = nil

    
    ya.dbg("No file selected")
    -- Custom condition: color recently modified files green
    if is_recently_modified(self._file, 24) then  -- Files modified in last 24 hours
        color = "green"
    -- Files modified in last week but not last 24 hours - yellow
    elseif is_recently_modified(self._file, 168) then  -- 168 hours = 7 days
        color = "yellow"
    -- Default yazi behavior for other cases
    elseif self._file:is_hovered() then
        color = self._file:is_dir() and "blue_light" or "white"
    elseif self._file:is_dir() then
        color = "blue"
    elseif self._file:is_link() then
        color = "cyan"
    elseif self._file:is_orphan() then
        color = "red"
    elseif self._file:is_block() then
        color = "yellow"
    elseif self._file:is_char() then
        color = "yellow"
    elseif self._file:is_fifo() then
        color = "yellow"
    elseif self._file:is_sock() then
        color = "magenta"
    elseif self._file:is_exec() and not self._file:is_sticky() then
        color = "green"
    elseif self._file:is_sticky() then
        color = "magenta"
    end

    if not color then
        return ui.Line {}
    end

    local icon = self._file:icon()
    if not icon then
        return ui.Line(self._file:name()):style(THEME.manager[color] or {})
    end

    return ui.Line {
        ui.Span("D"),
        ui.Span(icon.text):style(icon.style),
        ui.Span(" " .. self._file:name()):style(THEME.manager[color] or {}),
    }
end
