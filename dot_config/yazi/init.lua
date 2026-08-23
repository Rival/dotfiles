-- ~/.config/yazi/init.lua
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

-- yatline-extra (local fork of imsi32/yatline + 4th "extra" info line).
-- Replaces simple-status. Disk shown via disk-bar addon, dir size via dir-size addon.
-- Theme A: custom dark to match existing theme.toml (black bg, #e4e4e4 accents).
require("yatline-extra"):setup({
	-- Имена дисков для префиксов табов (DiskTabs) — та же таблица, что и у disk-bar
	disk_names = disk_names,

	section_separator = { open = "\238\130\182", close = "\238\130\180" }, -- U+E0B6 + U+E0B4, капсулы как в disk-bar
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },

	padding = { inner = 1, outer = 1 },

	style_a = {
		bg = "#0dcdcd",
		fg = "black",
		bg_mode = {
			normal = "#0dcdcd",
			select = "brightyellow",
			un_set = "brightred",
		},
	},
	style_b = { bg = "brightblack", fg = "brightwhite" },
	style_c = { bg = "black", fg = "brightwhite" },

	permissions_t_fg = "green",
	permissions_r_fg = "yellow",
	permissions_w_fg = "red",
	permissions_x_fg = "cyan",
	permissions_s_fg = "white",

	tab_width = 20,

	selected = { icon = "󰻭", fg = "yellow" },
	copied = { icon = "", fg = "green" },
	cut = { icon = "", fg = "red" },

	files = { icon = "", fg = "blue" },
	filtereds = { icon = "", fg = "magenta" },

	total = { icon = "󰮍", fg = "yellow" },
	success = { icon = "", fg = "green" },
	failed = { icon = "", fg = "red" },

	show_background = true,

	-- Выравнивание по началу средней колонки:
	--   extra       — левая часть от колонки
	--   extra_edge  — первые N компонентов extra слева остаются у края
	--                 (1 = 📁 размер под столбцом папок)
	--   status      — режим у края, остальное от колонки
	-- (число = доп. клетки после границы; false = выкл)
	current_col_align = { extra = 1, extra_edge = 1, status = 1 },

	display_header_line = true,
	display_status_line = true,
	display_extra_line = true,

	component_positions = { "header", "extra1", "tab", "status" },

	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs" },
			},
			section_b = {},
			section_c = {},
		},
		right = {
			section_a = {},
			section_b = {},
			section_c = {
				{ type = "coloreds", custom = false, name = "disk-bar" },
			},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {},
			section_c = {
				-- 📂 dirs · 📄 files, non-recursive (dir-count addon);
				-- hovered name/size убраны как бесполезные;
				-- всё в section_c — без серого фона section_b
				{ type = "coloreds", name = "dir-count" },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "cursor_position" },
			},
			section_b = {},
			section_c = {
				{ type = "string", name = "cursor_percentage" },
				{ type = "coloreds", name = "permissions" },
			},
		},
	},

	-- Extra line (yatline-extra fork), top:
	--   📁 dir size · cwd path · selected/copied counts · Σ selection size
	extra_lines = {
		{
			left = {
				section_a = {},
				section_b = {},
				section_c = {
					{ type = "coloreds", name = "dir-size" },
					{ type = "string", name = "tab_path", params = { true, 60, 25 } },
					-- false = не показывать счётчик файлов, true = скрывать нули
					{ type = "coloreds", name = "count", params = { false, true } },
					{ type = "coloreds", name = "sel-size" },
				},
			},
			right = {
				section_a = {},
			section_b = {},
				section_c = {},
			},
		},
	},
})

-- Canonical disk names loaded from a separate file (edit ~/.config/yazi/disk-names.lua)
local disk_names = {}
pcall(function()
	disk_names = dofile(os.getenv("HOME") .. "/.config/yazi/disk-names.lua") or {}
end)
require("disk-bar"):setup({ names = disk_names })
-- max_ms: кап времени walk'а. Полные размеры для всего, что проходит за кап;
-- не успело → "…" (частичный обход). Попап при выходе возможен только если
-- выйти в первые ~max_ms после входа в НЕЗАКЭШИРОВАННЫЙ dir — благодаря
-- дисковому кэшу (см. ниже) это один раз на папку, а не каждый запуск.
-- 1500 = выход всегда мгновенный, но большие папки останутся частичными.
-- Полный размер важнее — ставлю 10с; верни 1500 если раздражает попап.
--
-- Дисковый кэш (вкл по умолчанию): полные результаты живут в
-- ~/.cache/yazi/dir-size-cache.lua, переживают рестарт (повторный заход —
-- мгновенно), TTL 30 дней (persist_ttl_days), обрезанные/битые — не пишутся.
-- Выключить: persist_path = false.
require("dir-size"):setup({ max_ms = 10000, persist_ttl_days = 30 })
require("sel-size"):setup({ max_ms = 1500 })
require("dir-count"):setup()

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

    -- Custom linemode also work (example — uncomment and set a real `location` to enable;
    -- an entry WITHOUT `location` makes pref-by-location crash on every event)
    -- {
    --   location = ".*/abc",
    --   linemode = "size_and_mtime",
    -- },
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

require("custom-colors"):setup({
	default = "recent",
	presets = {
		recent = {
			scope = "linemode",
			dirs = true,
			rules = {
				{ max_age = 3600, fg = "green" },
				{ max_age = 14400, fg = "yellow" },
				{ max_age = 86400, fg = "red" },
			},
		},
	},
})

-- scoped-marks: закладки/маркеры после custom-colors (children_add не заменяет
-- его обёрнутые методы — порядок детерминирован и безопасен).
local scoped_opts = {}
local scoped_ok, scoped_value = pcall(dofile, os.getenv("HOME") .. "/.config/yazi/scoped-marks.lua")
if scoped_ok and type(scoped_value) == "table" then
	scoped_opts = scoped_value
else
	ya.notify({
		title = "scoped-marks",
		content = "scoped-marks.lua invalid; using defaults",
		timeout = 5,
	})
end
require("scoped-marks"):setup(scoped_opts)
