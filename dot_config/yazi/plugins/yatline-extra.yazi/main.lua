--- @since 25.12.29
--- @diagnostic disable: undefined-global, undefined-field
--- @alias Mode Mode Comes from Yazi.
--- @alias Rect Rect Comes from Yazi.
--- @alias Paragraph Paragraph Comes from Yazi.
--- @alias Line Line Comes from Yazi.
--- @alias Span Span Comes from Yazi.
--- @alias Color Color Comes from Yazi.

--==================--
-- Type Declaration --
--==================--

--- @enum Side
local Side = {
	LEFT = 0, -- The left side of either the header-line or status-line. [ LEFT ... ]
	RIGHT = 1, -- The right side of either the header-line or status-line. [ ... RIGHT]
}

--- @enum SeparatorType
local SeparatorType = {
	OUTER = 0, -- Separators on the outer side of sections. [ c o | c o | c o ... ] or [ ... o c | o c | o c ]
	INNER = 1, -- Separators on the inner side of sections. [ c i c | c i c | c i c ... ] or [ ... c i c | c i c | c i c ]
}

--- @enum ComponentType
local ComponentType = {
	A = 0, -- Components on the first section. [ A | | ... ] or [ ... | | A ]
	B = 1, -- Components on the second section. [ | B | ... ] or [ ... | B | ]
	C = 2, -- Components on the third section. [ | | C ... ] or [ ... C | | ]
}

--- @alias Colored [string, Color] Stores text and its foreground color.
--- @alias Coloreds Colored[] The array of Coloreds.

--- @generic T
--- @alias T T Type of the component.

--- @class Yatline
--- @field config YatlineConfig Configuration of Yatline.
--- @field string? {} Table that stores string components.
--- @field line? {} Table that stores Line components.
--- @field coloreds? {} Table that stores Coloreds components.
Yatline = {}

--- @class (exact) ComponentConfig
--- @field type string Defines the type of the component (T).
--- @field custom? boolean Toggles the usage of a function defined or name field.
--- @field name string | T Either defined function name or variable of defined type T.
--- @field params? {} Contains the parameters that can be used by the function called.

--- @class (exact) SideConfig
--- @field section_a ComponentConfig[] Array of configuration of components in the first section.
--- @field section_b ComponentConfig[] Array of configuration of components in the second section.
--- @field section_c ComponentConfig[] Array of configuration of components in the third section.

--- @class (exact) LineConfig
--- @field left SideConfig Configuration of the left side of the line.
--- @field right SideConfig Configuration of the right side of the line.

--- @class (exact) YatlineConfig
--- @field section_separator {open: string, close: string} Separators that are between sections.
--- @field part_separator {open: string, close: string} Separators that are between components.
--- @field inverse_separator {open: string, close: string} Separators that are used when foreground color of separator is reset.
--- @field padding {inner: integer, outer: integer} Number of space padding surronding the component.
--- @field style_a {bg: Color, fg: Color, bg_mode: {normal: Color, select: Color, un_set: Color}} Style of the first section.
--- @field style_b {bg: Color, fg: Color} Style of the second section.
--- @field style_c {bg: Color, fg: Color} Style of the third section.
--- @field permissions_t_fg Color Foreground color of the type of permission.
--- @field permissions_r_fg Color Foreground color of the read permission.
--- @field permissions_w_fg Color Foreground color of the write permission.
--- @field permissions_x_fg Color Foreground color of the execute permission.
--- @field permissions_s_fg Color Foreground color of the separators between permission.
--- @field tab_width integer Maximum tab width of the tabs component.
--- @field selected {icon: string, fg: Color} Configuration for the count of files that selected.
--- @field copied {icon: string, fg: Color} Configuration for the count of files that copied.
--- @field cut {icon: string, fg: Color} Configuration for the count of files that cut.
--- @field files {icon: string, fg: Color} Configuration for the count of files in the active tab.
--- @field filtereds {icon: string, fg: Color} Configuration for the count of files in the active tab that are filtered.
--- @field total {icon: string, fg: Color} Configuration for the count of progress tasks that finished.
--- @field success {icon: string, fg: Color} Configuration for the count of progress tasks that successed.
--- @field failed {icon: string, fg: Color} Configuration for the count of progress tasks that failed.
--- @field show_background boolean Toggle the visibility of the background where no component exists.
--- @field display_header_line boolean Toggle the visibility of the header-line.
--- @field display_status_line boolean Toggle the visibility of the status-line.
--- @field display_extra_line boolean Toggle the visibility of the extra-line (yatline-extra fork).
--- @field component_positions string[] Arrange positions of the Yazi sections ("header", "tab", "extra1".."extraN", "status").
--- @field header_line LineConfig Configuration of header-line components.
--- @field status_line LineConfig Configuration of status-line components.
--- @field extra_lines LineConfig[] Configuration of extra-line components, index N = position "extraN" (yatline-extra fork).
--- @field current_col_align {extra: number|boolean, extra_edge: number?, status: number|boolean} Align the left side of lines with the start of the current (middle) column; number = extra cells beyond the column start, false/nil = off. `extra_edge` = first N left section_c components of the extra line stay at the very left edge (0 = all aligned) (yatline-extra fork).
Yatline.config = {
	section_separator = { open = "", close = "" },
	part_separator = { open = "", close = "" },
	inverse_separator = { open = "", close = "" },

	padding = { inner = 1, outer = 1 },

	style_a = {
		bg = "white",
		fg = "black",
		bg_mode = {
			normal = "white",
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
	-- Префикс "иконка+роль" диска в имени таба, когда табы на разных дисках
	tab_disk_names = true,

	selected = { icon = "󰻭", fg = "yellow" },
	copied = { icon = "", fg = "green" },
	cut = { icon = "", fg = "red" },

	files = { icon = "", fg = "blue" },
	filtereds = { icon = "", fg = "magenta" },

	total = { icon = "󰮍", fg = "yellow" },
	success = { icon = "", fg = "green" },
	failed = { icon = "", fg = "red" },

	show_background = true,

	display_header_line = true,
	display_status_line = true,
	display_extra_line = false,

	component_positions = { "header", "tab", "status" },

	current_col_align = { extra = 1, extra_edge = 0, status = 1 },

	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs" },
			},
			section_b = {},
			section_c = {},
		},
		right = {
			section_a = {
				{ type = "string", name = "date", params = { "%A, %d %B %Y" } },
			},
			section_b = {
				{ type = "string", name = "date", params = { "%X" } },
			},
			section_c = {},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {
				{ type = "string", name = "hovered_size" },
			},
			section_c = {
				{ type = "string", name = "hovered_path" },
				{ type = "coloreds", name = "count" },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "cursor_position" },
			},
			section_b = {
				{ type = "string", name = "cursor_percentage" },
			},
			section_c = {
				{ type = "string", name = "hovered_file_extension", params = { true } },
				{ type = "coloreds", name = "permissions" },
			},
		},
	},

	extra_lines = {},
}

--=================--
-- Component Setup --
--=================--

--- Sets the background of style_a according to the tab's mode.
--- @param mode Mode The mode of the active tab.
--- @see cx.active.mode To get the active tab's mode.
local function set_mode_style(mode)
	if mode.is_select then
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.select
	elseif mode.is_unset then
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.un_set
	else
		Yatline.config.style_a.bg = Yatline.config.style_a.bg_mode.normal
	end
end

--- Helper function to apply style table to a component
--- @param component Span The component to style
--- @param style table The style table with fg and/or bg fields
local function apply_style_table(component, style)
	if not style then
		return component
	end
	-- Apply manually
	if style.fg then
		component:fg(style.fg)
	end
	if style.bg then
		component:bg(style.bg)
	end
	if style.bold then
		component:bold()
	end
	if style.dim then
		component:dim()
	end
	if style.italic then
		component:italic()
	end
	if style.underline then
		component:underline()
	end
	if style.blink then
		component:blink()
	end
	if style.blink_rapid then
		component:blink_rapid()
	end
	if style.reverse then
		component:reverse()
	end
	if style.hidden then
		component:hidden()
	end
	if style.crossed then
		component:crossed()
	end

	return component
end

--- Helper function to apply style table to a component
--- @param component Span The component to style
--- @param style table The style table with fg and/or bg fields
local function apply_style_table(component, style)
	if not style then
		return component
	end
	-- Apply manually
	if style.fg          then component:fg(style.fg)  end
	if style.bg          then component:bg(style.bg)  end
	if style.bold        then component:bold()        end
	if style.dim         then component:dim()         end
	if style.italic      then component:italic()      end
	if style.underline   then component:underline()   end
	if style.blink       then component:blink()       end
	if style.blink_rapid then component:blink_rapid() end
	if style.reverse     then component:reverse()     end
	if style.hidden      then component:hidden()      end
	if style.crossed     then component:crossed()     end
	return component
end

--- Sets the style of the component according to the its type.
--- @param component Span Component that will be styled.
--- @param component_type ComponentType Which section component will be in [ a | b | c ].
--- @see Style To see how to style, in Yazi's documentation.
local function set_component_style(component, component_type)
	if component_type == ComponentType.A then
		apply_style_table(component, Yatline.config.style_a):bold()
	elseif component_type == ComponentType.B then
		apply_style_table(component, Yatline.config.style_b)
	else
		apply_style_table(component, Yatline.config.style_c)
	end
end

--- Surronds component with paddings.
--- @param component string | Span | Line Component that will be connected to paddings.
--- @param component_type ComponentType Which section component will be in [ a | b | c ].
--- @param in_side Side Left or right side of the either header-line or status-line.
--- @return Line line A Line which is a component that has padding.
local function connect_padding(component, component_type, in_side)
	local inner = ui.Span(string.rep(" ", Yatline.config.padding.inner))
	local outer = ui.Span(string.rep(" ", Yatline.config.padding.outer))

	set_mode_style(cx.active.mode)
	set_component_style(inner, component_type)
	set_component_style(outer, component_type)

	if in_side == Side.LEFT then
		return ui.Line({ outer, component, inner })
	else
		return ui.Line({ inner, component, outer })
	end
end

--- Connects component to a separator.
--- @param component Span Component that will be connected to separator.
--- @param in_side Side Left or right side of the either header-line or status-line.
--- @param separator_type SeparatorType Where will there be a separator in the section.
--- @param separator_style {bg: string?, fg: string?} Holds the style of the separator.
--- @return Line line A Line which may have either both component and separator, or component.
local function connect_separator(component, in_side, separator_type, separator_style)
	local open, close
	if
		separator_type == SeparatorType.OUTER and not (separator_style.bg == "reset" and separator_style.fg == "reset")
	then
		open = ui.Span(Yatline.config.section_separator.open)
		close = ui.Span(Yatline.config.section_separator.close)

		if separator_style.fg == "reset" then
			if separator_style.bg ~= "" then
				open = ui.Span(Yatline.config.inverse_separator.open)
				close = ui.Span(Yatline.config.inverse_separator.close)

				separator_style.fg, separator_style.bg = separator_style.bg, separator_style.fg
			else
				return ui.Line({ component })
			end
		end
	else
		open = ui.Span(Yatline.config.part_separator.open)
		close = ui.Span(Yatline.config.part_separator.close)
	end

	apply_style_table(open, separator_style)
	apply_style_table(close, separator_style)

	if in_side == Side.LEFT then
		return ui.Line({ component, close })
	else
		return ui.Line({ open, component })
	end
end

--==================--
-- Helper Functions --
--==================--

--- Gets the file name from given file extension.
--- @param file_name string The name of a file whose extension will be taken.
--- @return string file_extension Extension of a file.
local function get_file_extension(file_name)
	local extension = file_name:match("^.+%.(.+)$")

	if extension == nil or extension == "" then
		return "null"
	else
		return extension
	end
end

--- Reverse the order of given array
--- @param array Line Array which wants to be reversed.
--- @return table reversed Reversed ordered given array.
local function reverse_order(array)
	local reversed = {}
	for i = #array, 1, -1 do
		table.insert(reversed, array[i])
	end

	return reversed
end

--- the number of characters in a UTF-8 string
--- @param s string The string to process.
--- @return integer The number of characters in the string.
local function utf8len(s)
	-- count the number of non-continuing bytes
	return select(2, s:gsub("[^\128-\193]", ""))
end

--- like string.sub() but i, j are utf8 strings
--- a utf8-safe string.sub()
--- @param s string The string to process.
--- @param i integer The start position.
--- @param j integer The end position.
--- @return string The substring.
local function utf8sub(s, i, j)
	-- pattern for matching UTF-8 characters
	local pattern = "[%z\1-\127\194-\244][\128-\191]*"

	-- helper function for position calculation
	--- @param pos integer The position of the character.
	--- @param len integer The length of the string.
	--- @return integer The relative position of the character.
	local function posrelat(pos, len)
		if pos < 0 then
			pos = len + pos + 1
		end
		return pos
	end

	-- helper function to iterate over UTF-8 chars
	local function chars(_s, no_subs)
		local function map(f)
			local _i = 0
			if no_subs then
				for b, e in _s:gmatch("()" .. pattern .. "()") do
					_i = _i + 1
					local c = e - b
					f(_i, c, b)
				end
			else
				for b, c in _s:gmatch("()(" .. pattern .. ")") do
					_i = _i + 1
					f(_i, c, b)
				end
			end
		end
		return coroutine.wrap(function()
			return map(coroutine.yield)
		end)
	end

	local l = utf8len(s)

	i = posrelat(i, l)
	j = j and posrelat(j, l) or l

	if i < 1 then
		i = 1
	end
	if j > l then
		j = l
	end

	if i > j then
		return ""
	end

	local diff = j - i
	local iter = chars(s, true)

	-- advance up to i
	for _ = 1, i - 1 do
		iter()
	end

	local c, b = select(2, iter())

	-- becareful with the edge case of empty string
	if not b then
		return ""
	end

	-- i and j are the same, single-character sub
	if diff == 0 then
		return string.sub(s, b, b + c - 1)
	end

	i = b

	-- advance up to j
	for _ = 1, diff - 1 do
		iter()
	end

	c, b = select(2, iter())

	return string.sub(s, i, b + c - 1)
end

--- Trims the filename if it is longer than the max_length.
--- @param filename string The name of a file which will be trimmed.
--- @param max_length integer Maximum length of the filename.
--- @param trim_length integer Length of the trimmed filename.
--- @return string trimmed_filename Trimmed filename.
local function trim_filename(filename, max_length, trim_length)
	if not max_length or not trim_length then
		return filename
	end

	-- Count UTF-8 characters
	local len = utf8len(filename)

	if len <= max_length then
		return filename
	end

	if len <= trim_length * 2 then
		return filename
	end

	return utf8sub(filename, 1, trim_length) .. "..." .. utf8sub(filename, len - trim_length + 1, len)
end

--========================--
-- Component String Group --
--========================--

Yatline.string = {}
Yatline.string.get = {}
Yatline.string.has_separator = true

--- Creates a component from given string according to other parameters.
--- @param string string The text which will be shown inside of the component.
--- @param component_type ComponentType Which section component will be in [ a | b | c ].
--- @return Line line Customized Line which follows desired style of the parameters.
--- @see set_mode_style To know how mode style selected.
--- @see set_component_style To know how component style applied.
function Yatline.string.create(string, component_type)
	local span = ui.Span(string)
	set_mode_style(cx.active.mode)
	set_component_style(span, component_type)

	return ui.Line({ span })
end

--- Gets the hovered file's name of the current active tab.
--- @param trimmed? boolean Whether to trim the filename if it's too long (default: false)
--- @param max_length? integer Maximum length of the filename (default: 24)
--- @param trim_length? integer Length of each end when trimming (default: 10)
--- @param show_symlink? boolean Whether to show symlink target (default: false)
--- @return string name Current active tab's hovered file's name
function Yatline.string.get:hovered_name(trimmed, max_length, trim_length, show_symlink)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10
	show_symlink = show_symlink or false

	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	local link_delimiter = " -> "
	local linked = (show_symlink and hovered.link_to ~= nil) and (link_delimiter .. tostring(hovered.link_to)) or ""

	if trimmed then
		local trimmed_name = trim_filename(hovered.name, max_length, trim_length)
		local trimmed_linked = #linked ~= 0
				and link_delimiter .. trim_filename(
					string.sub(linked, #link_delimiter + 1, -1),
					max_length,
					trim_length
				)
			or ""
		return trimmed_name .. trimmed_linked
	else
		return hovered.name .. linked
	end
end

--- Gets the hovered file's path of the current active tab.
--- @param trimmed? boolean Whether to trim the file path if it's too long (default: false)
--- @param max_length? integer Maximum length of the file path (default: 24)
--- @param trim_length? integer Length of each end when trimming (default: 10)
--- @return string path Current active tab's hovered file's path.
function Yatline.string.get:hovered_path(trimmed, max_length, trim_length)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10

	local hovered = cx.active.current.hovered
	if not hovered then
		return ""
	end

	if trimmed then
		return trim_filename(ya.readable_path(tostring(hovered.url)), max_length, trim_length)
	else
		return ya.readable_path(tostring(hovered.url))
	end
end

--- Gets the hovered file's size of the current active tab.
--- @return string size Current active tab's hovered file's size.
function Yatline.string.get:hovered_size()
	local hovered = cx.active.current.hovered
	if hovered then
		return ya.readable_size(hovered:size() or hovered.cha.len)
	else
		return ""
	end
end

--- Gets the hovered file's path of the current active tab.
--- @return string mime Current active tab's hovered file's mime.
function Yatline.string.get:hovered_mime()
	local hovered = cx.active.current.hovered
	if hovered then
		return hovered:mime()
	else
		return ""
	end
end

--- Gets the hovered file's user and group ownership of the current active tab.
--- Unix-like systems only.
--- @return string ownership Current active tab's hovered file's user and group ownership.
function Yatline.string.get:hovered_ownership()
	local hovered = cx.active.current.hovered

	if hovered then
		if not hovered.cha.uid or not hovered.cha.gid then
			return ""
		end

		local username = ya.user_name(hovered.cha.uid) or tostring(hovered.cha.uid)
		local groupname = ya.group_name(hovered.cha.gid) or tostring(hovered.cha.gid)

		return username .. ":" .. groupname
	else
		return ""
	end
end

--- Gets the hovered file's extension of the current active tab.
--- @param show_icon boolean Whether or not an icon will be shown.
--- @return string file_extension Current active tab's hovered file's extension.
function Yatline.string.get:hovered_file_extension(show_icon)
	local hovered = cx.active.current.hovered

	if hovered then
		local cha = hovered.cha

		local name
		if cha.is_dir then
			name = "dir"
		else
			name = get_file_extension(hovered.url.name)
		end

		if show_icon then
			local icon = hovered:icon().text
			return icon .. " " .. name
		else
			return name
		end
	else
		return ""
	end
end

--- Gets the path of the current active tab.
--- @param trimmed? boolean Whether to trim the current active tab's path if it's too long (default: false)
--- @param max_length? integer Maximum length of the current active tab's path (default: 24)
--- @param trim_length? integer Length of each end when trimming (default: 10)
--- @return string path Current active tab's path.
function Yatline.string.get:tab_path(trimmed, max_length, trim_length)
	trimmed = trimmed or false
	max_length = max_length or 24
	trim_length = trim_length or 10

	local cwd = cx.active.current.cwd
	local filter = cx.active.current.files.filter
	local finder = cx.active.finder

	local t = {}
	if cwd.is_search then
		t[#t + 1] = string.format("search: %s", cwd.domain)
	end
	if filter then
		t[#t + 1] = string.format("filter: %s", filter)
	end
	if finder then
		t[#t + 1] = string.format("find: %s", finder)
	end

	local suffix
	if #t ~= 0 then
		suffix = " (" .. table.concat(t, ", ") .. ")"
	else
		suffix = ""
	end

	if trimmed then
		return trim_filename(ya.readable_path(tostring(cwd)), max_length, trim_length) .. suffix
	else
		return ya.readable_path(tostring(cwd)) .. suffix
	end
end

--- Gets the filtered query.
--- @param key? string Key value that indicates filtered query (default: "filter:")
--- @return string query Filtered query.
function Yatline.string.get:filter_query(key)
	key = key or "filter:"

	local filter = cx.active.current.files.filter

	if filter then
		return string.format("%s %s", key, tostring(filter))
	else
		return ""
	end
end

--- Gets the searched query.
--- @param key? string Key value that indicates searched query (default: "search:")
--- @return string query Searched query.
function Yatline.string.get:search_query(key)
	key = key or "search:"

	local cwd = cx.active.current.cwd

	if cwd.is_search then
		return string.format("%s %s", key, cwd.domain)
	else
		return ""
	end
end

--- Gets the finded query.
--- @param key? string Key value that indicates finded query (default: "find:")
--- @return string query Finded query.
function Yatline.string.get:finder_query(key)
	key = key or "find:"

	local finder = cx.active.finder

	if finder then
		return string.format("%s %s", key, tostring(finder))
	else
		return ""
	end
end

--- Gets the mode of active tab.
--- @return string mode Active tab's mode.
function Yatline.string.get:tab_mode()
	local mode = tostring(cx.active.mode):upper()
	if mode == "UNSET" then
		mode = "UN-SET"
	end

	return mode
end

--- Gets the number of files in the current active tab.
--- @return string num_files Number of files in the current active tab.
function Yatline.string.get:tab_num_files()
	return tostring(#cx.active.current.files)
end

--- Gets the cursor position in the current active tab.
--- @return string cursor_position Current active tab's cursor position.
function Yatline.string.get:cursor_position()
	local cursor = cx.active.current.cursor
	local length = #cx.active.current.files

	if length ~= 0 then
		return string.format("%d/%d", cursor + 1, length)
	else
		return "0"
	end
end

--- Gets the cursor position as percentage which is according to the number of files inside of current active tab.
--- @return string percentage Percentage of current active tab's cursor position and number of percentages.
function Yatline.string.get:cursor_percentage()
	local percentage = 0
	local cursor = cx.active.current.cursor
	local length = #cx.active.current.files
	if cursor ~= 0 and length ~= 0 then
		percentage = math.floor((cursor + 1) * 100 / length)
	end

	if percentage == 0 then
		return "Top"
	elseif percentage == 100 then
		return "Bot"
	else
		return string.format("%d%%", percentage)
	end
end

--- Gets the local date or time values.
--- @param format string Format for giving desired date or time values.
--- @return string date Date or time values.
--- @see os.date To see how format works.
function Yatline.string.get:date(format)
	return tostring(os.date(format))
end

--======================--
-- Component Line Group --
--======================--

-- ── DiskTabs: имена дисков в именах табов ───────────────────────
-- Когда табы сидят на РАЗНЫХ дисках/томах, каждый таб получает префикс
-- "иконка+роль" (из ~/.config/yazi/disk-names.lua). Все табы на одном
-- диске — рендер как раньше, без шума.
-- Источник — /proc/self/mounts, читается ОДИН раз и кэшируется: никаких
-- подпроцессов на рендер (урок Ape/mount-points.yazi с его findmnt).
local DiskTabs = { _mounts = nil, _names = nil }

-- Псевдо-FS — не диски: таб в /tmp считается сидящим на корневом томе
local DISKTABS_PSEUDO_FS = {
	tmpfs = true, devtmpfs = true, ramfs = true, proc = true, sysfs = true,
	devpts = true, efivarfs = true, cgroup = true, cgroup2 = true,
	securityfs = true, debugfs = true, tracefs = true, pstore = true,
	bpf = true, autofs = true, squashfs = true, erofs = true, overlay = true,
	fusectl = true, configfs = true, hugetlbfs = true, mqueue = true,
	nsns = true, rpc_pipefs = true, binfmt_misc = true, iso9660 = true,
}

-- "\\040"-стиль восьмеричных экранирований в поле маунтпоинта
local function disktabs_unescape(s)
	return (s:gsub("\\(%d%d%d)", function(o)
		return string.char(tonumber(o, 8))
	end))
end

-- nvme1n1p5 → nvme1n1, sda1 → sda (логика как в disk-bar.yazi)
local function disktabs_physical(source)
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

-- Короткая метка диска: "🪟 Windows" > "🗄️ Crucial P3" > "nvme1n1p2"
local function disktabs_label(source, names)
	names = names or {}
	local key = source:match("^([^:]+)") or source
	local role = (names.roles or {})[source] or (names.roles or {})[key]
	if role and role ~= "" then
		local icon = ((names.icons or {}).roles or {})[role]
		if icon and icon ~= "" then
			return icon .. " " .. role
		end
		return role
	end
	local pd = disktabs_physical(source)
	local model = pd and (names.models or {})[pd] or nil
	if model then
		local icon = ((names.icons or {}).disks or {})[pd]
		if icon and icon ~= "" then
			return icon .. " " .. model
		end
		return model
	end
	return key:gsub("^/dev/", "")
end

-- Чистая: текст /proc/self/mounts → { { mnt, source }, … },
-- отсортировано по убыванию длины маунтпоинта (longest-prefix первым).
function DiskTabs.parse_mounts(text)
	local mounts = {}
	for line in text:gmatch("[^\n]+") do
		local source, mnt, fstype = line:match("^(%S+)%s+(%S+)%s+(%S+)")
		if source and mnt and fstype and not DISKTABS_PSEUDO_FS[fstype] then
			mounts[#mounts + 1] = { mnt = disktabs_unescape(mnt), source = source }
		end
	end
	table.sort(mounts, function(a, b)
		return #a.mnt > #b.mnt
	end)
	return mounts
end

-- Путь принадлежит маунтпоинту (longest-prefix; корень "/" ловит любой абсолютный путь)
local function disktabs_under(path, mnt)
	if mnt == "/" then
		return path:sub(1, 1) == "/"
	end
	return path == mnt
		or (#path > #mnt and path:sub(1, #mnt) == mnt and path:sub(#mnt + 1, #mnt + 1) == "/")
end

-- Чистая: путь → { source, label } по принципу longest-prefix.
-- Идентичность диска — источник: sshfs "user@host:/x" схлопывается до "user@host".
function DiskTabs.resolve(path, mounts, names)
	path = tostring(path)
	local found
	for _, m in ipairs(mounts) do
		if disktabs_under(path, m.mnt) then
			found = m
			break
		end
	end
	if not found then
		return { source = "?", label = "?" }
	end
	local source = found.source:match("^([^:]+)") or found.source
	return { source = source, label = disktabs_label(found.source, names) }
end

-- Чистая: список путей табов → массив меток, либо nil если диск один/таб один
function DiskTabs.prefixes(paths, mounts, names)
	if #paths < 2 then
		return nil
	end
	local labels, seen = {}, {}
	for i, p in ipairs(paths) do
		local r = DiskTabs.resolve(p, mounts, names)
		labels[i] = r.label
		seen[r.source] = true
	end
	local n = 0
	for _ in pairs(seen) do
		n = n + 1
	end
	if n < 2 then
		return nil
	end
	return labels
end

-- Рендер-обёртка: кэш маунтов/имён (лениво, один раз за сессию)
function DiskTabs.prefixes_cached(paths)
	if not DiskTabs._mounts then
		local f = io.open("/proc/self/mounts")
		local text = f and f:read("*a") or ""
		if f then
			f:close()
		end
		DiskTabs._mounts = DiskTabs.parse_mounts(text)
	end
	if not DiskTabs._names then
		local ok, v = pcall(dofile, os.getenv("HOME") .. "/.config/yazi/disk-names.lua")
		DiskTabs._names = (ok and type(v) == "table") and v or {}
	end
	return DiskTabs.prefixes(paths, DiskTabs._mounts, DiskTabs._names)
end

-- Тестовый хук: фиксированные маунты/имёна вместо живой системы
function DiskTabs.inject(mounts_text, names)
	DiskTabs._mounts = DiskTabs.parse_mounts(mounts_text)
	DiskTabs._names = names or {}
end

Yatline.disk_tabs = DiskTabs

Yatline.line = {}
Yatline.line.get = {}
Yatline.line.has_separator = false

--- To follow component group naming and functions, returns the given line without any changes.
--- @param line Line The line already pre-defined.
--- @param component_type ComponentType Which section component will be in [ a | b | c ]. Will not be used.
--- @return Line line The given line as an input.
function Yatline.line.create(line, component_type)
	return line
end

--- Creates and returns line component for tabs.
--- @param side? string Left or right side of the either header-line or status-line.
--- @return Line line Customized Line which contains tabs.
--- @see set_mode_style To know how mode style selected.
--- @see set_component_style To know how component style applied.
--- @see connect_padding To know how components have paddings.
--- @see connect_separator To know how component and separator connected.
function Yatline.line.get:tabs(side)
	side = side or "left"

	local tabs = #cx.tabs
	local lines = {}

	local in_side
	if side == "left" then
		in_side = Side.LEFT
	else
		in_side = Side.RIGHT
	end

	-- Диски в именах табов: префикс "иконка+роль" только когда табы
	-- на разных дисках (иначе рендер как раньше)
	local disk_prefixes = nil
	if Yatline.config.tab_disk_names and tabs > 1 then
		local paths = {}
		for i = 1, tabs do
			local cur = cx.tabs[i].current
			paths[i] = (cur and cur.cwd) and tostring(cur.cwd) or tostring(cx.tabs[i])
		end
		disk_prefixes = DiskTabs.prefixes_cached(paths)
	end

	for i = 1, tabs do
		local text = tostring(i)
		if Yatline.config.tab_width > 2 then
			local name = cx.tabs[i].name
			local max = Yatline.config.tab_width
			if disk_prefixes and disk_prefixes[i] then
				name = disk_prefixes[i] .. "/" .. name
				max = max + #disk_prefixes[i] + 1
			end
			text = ui.truncate(text .. " " .. name, { max = max })
		end

		local separator_style = { bg = nil, fg = nil }
		if i == cx.tabs.idx then
			local tab = connect_padding(text, ComponentType.A, in_side)
			set_mode_style(cx.tabs[i].mode)
			set_component_style(tab, ComponentType.A)

			if Yatline.config.style_a.bg ~= "reset" or Yatline.config.show_background then
				separator_style.fg = Yatline.config.style_a.bg
				if Yatline.config.show_background then
					separator_style.bg = Yatline.config.style_c.bg
				end

				local line = connect_separator(tab, in_side, SeparatorType.OUTER, separator_style)
				-- Активный таб ВСЕГДА рисует свою ЛЕВУЮ капсулу fg-стилем
				-- (как disk-bar красит свои). Стыковая закраска bg-стилем
				-- у круглых капсул выглядит тёмным пятном, поэтому стык
				-- на левой стороне ниже отключён — один механизм на оба ушка.
				if in_side == Side.LEFT then
					local open = ui.Span(Yatline.config.section_separator.open)
					apply_style_table(open, separator_style)
					line = ui.Line({ open, line })
				end
				lines[#lines + 1] = line
			else
				separator_style.fg = Yatline.config.style_a.fg

				lines[#lines + 1] = connect_separator(tab, in_side, SeparatorType.INNER, separator_style)
			end
		else
			local tab = ui.Span(text)
			local inner = ui.Span(string.rep(" ", Yatline.config.padding.inner))
			local outer = ui.Span(string.rep(" ", Yatline.config.padding.outer))

			if Yatline.config.show_background then
				set_component_style(inner, ComponentType.C)
				set_component_style(outer, ComponentType.C)
				set_component_style(tab, ComponentType.C)
			else
				apply_style_table(tab, { fg = Yatline.config.style_c.fg })
			end

			if in_side == Side.LEFT then
				tab = ui.Line({ outer, tab, inner })
			else
				tab = ui.Line({ inner, tab, outer })
			end

			-- Стык idx-1 рисовал ЛЕВУЮ капсулу активного таба инверсией
			-- (bg=циан, fg=чёрный) — на круглых капсулах это тёмное пятно.
			-- Левая сторона теперь рисует обе капсулы сама (см. ветку выше);
			-- стык оставлен только правой половине строки с её обратным
			-- порядком рендера, где своя капсула не рисуется.
			if i == cx.tabs.idx - 1 and in_side == Side.RIGHT then
				set_mode_style(cx.tabs[i + 1].mode)

				local open, close
				if
					Yatline.config.style_a.bg ~= "reset"
					or (Yatline.config.show_background and Yatline.config.style_c.bg ~= "reset")
				then
					if
						not Yatline.config.show_background
						or (Yatline.config.show_background and Yatline.config.style_c.bg == "reset")
					then
						separator_style.fg = Yatline.config.style_a.bg
						if Yatline.config.show_background then
							separator_style.bg = Yatline.config.style_c.bg
						end

						open = ui.Span(Yatline.config.inverse_separator.open)
						close = ui.Span(Yatline.config.inverse_separator.close)
					else
						separator_style.bg = Yatline.config.style_a.bg
						if Yatline.config.show_background then
							separator_style.fg = Yatline.config.style_c.bg
						end

						open = ui.Span(Yatline.config.section_separator.open)
						close = ui.Span(Yatline.config.section_separator.close)
					end
				else
					separator_style.fg = Yatline.config.style_c.fg

					open = ui.Span(Yatline.config.part_separator.open)
					close = ui.Span(Yatline.config.part_separator.close)
				end

				apply_style_table(open, separator_style)
				apply_style_table(close, separator_style)

				if in_side == Side.LEFT then
					lines[#lines + 1] = ui.Line({ tab, close })
				else
					lines[#lines + 1] = ui.Line({ open, tab })
				end
			else
				separator_style.fg = Yatline.config.style_c.fg
				if Yatline.config.show_background then
					separator_style.bg = Yatline.config.style_c.bg
				end

				lines[#lines + 1] = connect_separator(tab, in_side, SeparatorType.INNER, separator_style)
			end
		end
	end

	if in_side == Side.RIGHT then
		return ui.Line(reverse_order(lines))
	else
		return ui.Line(lines)
	end
end

--==========================--
-- Component Coloreds Group --
--==========================--

Yatline.coloreds = {}
Yatline.coloreds.get = {}
Yatline.coloreds.has_separator = true

--- Creates a component from given Coloreds according to other parameters.
--- The component it created, can contain multiple strings with different foreground color.
--- @param coloreds Coloreds The array which contains an array which contains text which will be shown inside of the component and its foreground color.
--- @param component_type ComponentType Which section component will be in [ a | b | c ].
--- @return Line line Customized Line which follows desired style of the parameters.
--- @see set_mode_style To know how mode style selected.
--- @see set_component_style To know how component style applied.
function Yatline.coloreds.create(coloreds, component_type)
	set_mode_style(cx.active.mode)

	local spans = {}
	for i, colored in ipairs(coloreds) do
		local span = ui.Span(colored[1])
		set_component_style(span, component_type)
		span:fg(colored[2])

		spans[i] = span
	end

	return ui.Line(spans)
end

--- Gets the hovered file's permissions of the current active tab.
--- Unix-like systems only.
--- @return Coloreds? coloreds Current active tab's hovered file's permissions
function Yatline.coloreds.get:permissions()
	local hovered = cx.active.current.hovered

	if hovered then
		local perm = hovered.cha:perm()

		if perm then
			local coloreds = {}

			for i = 1, #perm do
				local c = perm:sub(i, i)

				local fg = Yatline.config.permissions_t_fg
				if c == "-" then
					fg = Yatline.config.permissions_s_fg
				elseif c == "r" then
					fg = Yatline.config.permissions_r_fg
				elseif c == "w" then
					fg = Yatline.config.permissions_w_fg
				elseif c == "x" or c == "s" or c == "S" or c == "t" or c == "T" then
					fg = Yatline.config.permissions_x_fg
				end

				table.insert(coloreds, { c, fg })
			end

			return coloreds
		else
			return nil
		end
	else
		return nil
	end
end

--- Gets the number of selected and yanked files and also number of files or filtered files of the active tab.
--- @param filter? boolean Whether or not number of files (or filtered files) will be shown.
--- @param zero_check? boolean Whether or not counts will be shown if count is zero.
--- @return Coloreds? coloreds Active tab's number of selected and yanked files and also number of files or filtered files
function Yatline.coloreds.get:count(filter, zero_check)
	filter = filter or false
	zero_check = zero_check or false

	local num_yanked = #cx.yanked
	local num_selected = #cx.active.selected
	local num_files = #cx.active.current.files

	local coloreds = {}

	if filter then
		local files_count_fg, files_count_icon
		if cx.active.current.files.filter or cx.active.current.cwd.is_search then
			files_count_fg = Yatline.config.filtereds.fg
			files_count_icon = Yatline.config.filtereds.icon
		else
			files_count_fg = Yatline.config.files.fg
			files_count_icon = Yatline.config.files.icon
		end

		if (zero_check and num_files > 0) or not zero_check then
			table.insert(coloreds, { string.format("%s %d", files_count_icon, num_files), files_count_fg })
		end
	end

	if (zero_check and num_selected > 0) or not zero_check then
		if #coloreds > 0 then
			table.insert(coloreds, { " ", Yatline.config.selected.fg })
		end

		table.insert(
			coloreds,
			{ string.format("%s %d", Yatline.config.selected.icon, num_selected), Yatline.config.selected.fg }
		)
	end

	if (zero_check and num_yanked > 0) or not zero_check then
		local yanked_fg, yanked_icon
		if cx.yanked.is_cut then
			yanked_fg = Yatline.config.cut.fg
			yanked_icon = Yatline.config.cut.icon
		else
			yanked_fg = Yatline.config.copied.fg
			yanked_icon = Yatline.config.copied.icon
		end

		if #coloreds > 0 then
			table.insert(coloreds, { " ", yanked_fg })
		end

		table.insert(coloreds, { string.format("%s %d", yanked_icon, num_yanked), yanked_fg })
	end

	if #coloreds > 0 then
		return coloreds
	else
		return nil
	end
end

--- Gets the number of task states.
--- @param zero_check? boolean Whether or not counts will be shown if count is zero.
--- @return Coloreds? coloreds Number of task states.
function Yatline.coloreds.get:task_states(zero_check)
	zero_check = zero_check or false

	local summary = cx.tasks.summary
	local coloreds = {}

	if (zero_check and summary.total > 0) or not zero_check then
		table.insert(
			coloreds,
			{ string.format("%s %d", Yatline.config.total.icon, summary.total), Yatline.config.total.fg }
		)
	end

	if (zero_check and summary.success > 0) or not zero_check then
		if #coloreds > 0 then
			table.insert(coloreds, { " ", Yatline.config.success.fg })
		end

		table.insert(
			coloreds,
			{ string.format("%s %d", Yatline.config.success.icon, summary.success), Yatline.config.success.fg }
		)
	end

	if (zero_check and summary.failed > 0) or not zero_check then
		if #coloreds > 0 then
			table.insert(coloreds, { " ", Yatline.config.failed.fg })
		end

		table.insert(
			coloreds,
			{ string.format("%s %d", Yatline.config.failed.icon, summary.failed), Yatline.config.failed.fg }
		)
	end

	if #coloreds > 0 then
		return coloreds
	else
		return nil
	end
end

--- Gets colored which contains string based component's string and desired foreground color.
--- @param component_name string String based component's name.
--- @param fg Color Desired foreground color.
--- @param params? table Array of parameters of string based component. It is optional.
--- @return Coloreds? coloreds Array of solely array of string based component's string and desired foreground color.
function Yatline.coloreds.get:string_based_component(component_name, fg, params)
	local getter = Yatline.string.get[component_name]

	if getter then
		local output
		if params then
			output = getter(Yatline.string.get, table.unpack(params))
		else
			output = getter()
		end

		if output ~= nil and output ~= "" then
			return { { output, fg } }
		end
	end

	return nil
end

--===============--
-- Configuration --
--===============--

--- Configure separators if it is need to be added to the components.
--- Connects them with each component.
--- @param section_components [Line, boolean][] Array of components in one of the sections.
--- @param component_type ComponentType Which section component will be in [ a | b | c ].
--- @param in_side Side Left or right side of the either header-line or status-line.
--- @param num_section_b_components integer Number of components in section-b.
--- @param num_section_c_components integer Number of components in section-c.
--- @return table section_line_components Array of line components whether or not connected with separators.
--- @see connect_padding To know how components have paddings.
--- @see connect_separator To know how component and separator connected.
local function config_components_separators(
	section_components,
	component_type,
	in_side,
	num_section_b_components,
	num_section_c_components
)
	local num_section_components = #section_components
	local section_line_components = {}
	for i, component in ipairs(section_components) do
		if component[2] == true then -- Does component have separator?
			local separator_style = { bg = nil, fg = nil }

			local separator_type
			if i ~= num_section_components then -- Does component is not at the end of the section?
				separator_type = SeparatorType.INNER

				if component_type == ComponentType.A then
					separator_style = Yatline.config.style_a
				elseif component_type == ComponentType.B then
					separator_style = Yatline.config.style_b
				else
					separator_style = Yatline.config.style_c
				end
			else -- Does component is at the end of the section?
				separator_type = SeparatorType.OUTER

				if component_type == ComponentType.A then
					separator_style.fg = Yatline.config.style_a.bg
				elseif component_type == ComponentType.B then
					separator_style.fg = Yatline.config.style_b.bg
				else
					separator_style.fg = Yatline.config.style_c.bg
				end

				if component_type == ComponentType.A and num_section_b_components ~= 0 then
					separator_style.bg = Yatline.config.style_b.bg
				elseif num_section_c_components == 0 or component_type == ComponentType.C then
					if Yatline.config.show_background then
						separator_style.bg = Yatline.config.style_c.bg
					end
				else
					separator_style.bg = Yatline.config.style_c.bg
				end
			end

			component[1] = connect_padding(component[1], component_type, in_side)
			section_line_components[i] = connect_separator(component[1], in_side, separator_type, separator_style)
		else
			section_line_components[i] = component[1]
		end
	end

	return section_line_components
end

--- Creates configured section according to its components' config.
--- @param section ComponentConfig[] Array of components' config in a section.
--- @param component_type ComponentType Which section that components will be.
--- @return [Line, boolean][] section_components Configured components array whose components are in section.
local function config_section(section, component_type)
	--- @type [Line, boolean][]
	local section_components = {}

	for _, component in ipairs(section) do
		local component_group = Yatline[component.type]

		if component_group then -- Does component group exist?
			if component.custom then -- Does component is custom?
				if component.name ~= nil and component.name ~= "" and #component.name ~= 0 then -- Does component name is valid?
					section_components[#section_components + 1] = -- Insert component to the table.
						{ component_group.create(component.name, component_type), component_group.has_separator }
				end
			else
				local getter = component_group.get[component.name] -- Get component function that will be called.

				if getter then -- Does function exist?
					local output -- Output of the function.
					if component.params then -- Does component function has parameters?
						output = getter(component_group.get, table.unpack(component.params))
					else
						output = getter()
					end

					if output ~= nil and output ~= "" then -- Does component is not empty?
						section_components[#section_components + 1] = -- Insert component to the table.
							{ component_group.create(output, component_type), component_group.has_separator }
					end
				end
			end
		end
	end

	return section_components
end

--- Automatically creates and configures either header-line or status-line.
--- @param side SideConfig Configuration of either left or right side.
--- @param in_side Side Which side components will be.
--- @return Line left_line Consist of components that are in left side of the line.
--- @return Line right_line Consist of components that are in right side of the line.
--- @see config_section To know how components are gotten from sections' config.
--- @see config_components_separators To know how components are connected with separators.
local function config_line(side, in_side)
	-- Configures components of sections.
	local section_a_components = config_section(side.section_a, ComponentType.A)
	local section_b_components = config_section(side.section_b, ComponentType.B)
	local section_c_components = config_section(side.section_c, ComponentType.C)

	local num_section_b_components = #section_b_components
	local num_section_c_components = #section_c_components

	-- Connects components of section by separators.
	local section_a_line_components = config_components_separators(
		section_a_components,
		ComponentType.A,
		in_side,
		num_section_b_components,
		num_section_c_components
	)
	local section_b_line_components = config_components_separators(
		section_b_components,
		ComponentType.B,
		in_side,
		num_section_b_components,
		num_section_c_components
	)
	local section_c_line_components = config_components_separators(
		section_c_components,
		ComponentType.C,
		in_side,
		num_section_b_components,
		num_section_c_components
	)

	if in_side == Side.RIGHT then -- Reverse the order of the components if it is in the right side.
		section_a_line_components = reverse_order(section_a_line_components)
		section_b_line_components = reverse_order(section_b_line_components)
		section_c_line_components = reverse_order(section_c_line_components)
	end

	-- Combines components of section into single components.
	local section_a_line = ui.Line(section_a_line_components)
	local section_b_line = ui.Line(section_b_line_components)
	local section_c_line = ui.Line(section_c_line_components)

	if in_side == Side.LEFT then
		return ui.Line({ section_a_line, section_b_line, section_c_line })
	else
		return ui.Line({ section_c_line, section_b_line, section_a_line })
	end
end

--- Checks if either header-line or status-line contains components.
--- @param line LineConfig Configuration of either header-line or status-line.
--- @return boolean show_line Returns yes if it contains components, otherwise returns no.
local function show_line(line)
	for _, side in pairs(line) do
		for _, section in pairs(side) do
			if #section ~= 0 then
				return true
			end
		end
	end

	return false
end

--- Creates and configures paragraph which is used as left or right of either
--- header-line or status-line.
--- @param area Rect The area where paragraph will be placed in.
--- @param line? Line The line which used in paragraph. It is optional.
--- @return Paragraph paragraph Configured parapgraph.
local function config_paragraph(area, line)
	local line_array = { line } or {}
	if Yatline.config.show_background then
		return apply_style_table(ui.Text(line_array):area(area), Yatline.config.style_c)
	else
		return ui.Text(line_array):area(area)
	end
end

--- Fills the missing sides/sections of a line config with empty tables.
--- @param line LineConfig Configuration of a line.
local function fill_line_sections(line)
	if type(line) ~= "table" then
		return
	end
	for _, side in ipairs({ "left", "right" }) do
		if line[side] then
			for _, section in ipairs({ "section_a", "section_b", "section_c" }) do
				line[side][section] = line[side][section] or {}
			end
		else
			line[side] = {}
			for _, section in ipairs({ "section_a", "section_b", "section_c" }) do
				line[side][section] = {}
			end
		end
	end
end

--- Reads a numeric field from a Rect (userdata or table), nil if absent.
local function rect_field(rect, key)
	if rect == nil then
		return nil
	end
	local ok, v = pcall(function()
		return rect[key]
	end)
	if ok and type(v) == "number" then
		return v
	end
	return nil
end

--- X coordinate of the current (middle) column. Prefers the live layout
--- state via ui.area("current") (registered by the Current preset each
--- render); falls back to ratio math when unavailable.
local function current_col_x(area)
	local ok, r = pcall(function()
		return ui.area("current")
	end)
	local x = ok and rect_field(r, "x") or nil
	if x then
		return x
	end

	local ratio = rt and rt.mgr and rt.mgr.ratio or nil
	local w = rect_field(area, "w")
	if ratio and ratio.all and ratio.all > 0 and w then
		return math.floor(w * ratio.parent / ratio.all + 0.5)
	end
	return nil
end

--- Left padding (cells) to align a line's left side with the start of the
--- current (middle) column. `conf`: false/nil = off, number = extra cells
--- beyond the column start (1 lands on the file names, past the border).
local function align_pad(area, conf)
	if not conf or area == nil then
		return 0
	end
	local x = current_col_x(area)
	if not x then
		return 0
	end
	local base = rect_field(area, "x") or 0
	local w = rect_field(area, "w") or 0
	local pad = x + (tonumber(conf) or 0) - base
	if pad < 0 or w - pad < 8 then -- keep at least 8 drawable cells
		return 0
	end
	return pad
end

--- Builds a Line from a SUBSET of the side's sections. Separator styling
--- matches the full-line rendering (real section counts are used), so a
--- split render looks identical to the joined one. Used to keep the
--- status section_a (mode pill) at the very left edge while sections
--- b+c start at the current column.
--- @param side SideConfig Configuration of one side of a line.
--- @param in_side Side Left or right side.
--- @param names string[] Sections to include, in order.
local function config_line_sections(side, in_side, names)
	local sections = {
		section_a = config_section(side.section_a or {}, ComponentType.A),
		section_b = config_section(side.section_b or {}, ComponentType.B),
		section_c = config_section(side.section_c or {}, ComponentType.C),
	}
	local num_b, num_c = #sections.section_b, #sections.section_c

	local lines = {}
	for _, name in ipairs(names) do
		local ctype = ComponentType.C
		if name == "section_a" then
			ctype = ComponentType.A
		elseif name == "section_b" then
			ctype = ComponentType.B
		end
		local comps = config_components_separators(sections[name], ctype, in_side, num_b, num_c)
		if in_side == Side.RIGHT then
			comps = reverse_order(comps)
		end
		lines[#lines + 1] = ui.Line(comps)
	end
	return ui.Line(lines)
end

return {
	setup = function(_, config, pre_theme)
		-- Имена дисков для DiskTabs можно передать явно (как в disk-bar),
		-- иначе лениво читается ~/.config/yazi/disk-names.lua
		if config and config.disk_names then
			DiskTabs._names = config.disk_names
		end

		if config then
			-- Fills the sections that are not given if the line exists.
			for _, line_name in ipairs({ "header_line", "status_line" }) do
				if config[line_name] then
					fill_line_sections(config[line_name])
				end
			end
			if config.extra_lines then
				for _, line in ipairs(config.extra_lines) do
					fill_line_sections(line)
				end
			end

			-- Get the current theme according to the light/dark mode. (default: config.theme)
			config.theme = (not rt.term.light and config.theme_dark)
				or (rt.term.light and config.theme_light)
				or config.theme

			-- Extracts theme fields to the config unless that fields does not exists.
			if config.theme then
				for key, value in pairs(config.theme) do
					if not config[key] then
						config[key] = value
					end
				end
			end

			-- Extracts config fields to the YatlineConfig if that fields exists.
			-- (yatline-extra: `~= nil` instead of truthiness, so boolean options
			-- defaulting to false can still be overridden from user config)
			for key, value in pairs(config) do
				if Yatline.config[key] ~= nil then
					Yatline.config[key] = value
				end
			end
		end

		-- Extracts pre_theme fields to the YatlineConfig if that fields exists.
		if pre_theme then
			for key, value in pairs(pre_theme) do
				if Yatline.config[key] ~= nil then
					Yatline.config[key] = value
				end
			end
		end

		if Yatline.config.display_header_line then -- Controls displaying header-line.
			if show_line(Yatline.config.header_line) then -- Controls recoding of header-line.
				-- Empties default Yazi header-line.
				Header._left = {}
				Header._right = {}

				Header.redraw = function(self)
					-- Gets Yazi components.
					local right = self:children_redraw(self.RIGHT)
					self._right_width = right:width()
					local left = self:children_redraw(self.LEFT)

					-- Gets Yatline components.
					local left_line = config_line(Yatline.config.header_line.left, Side.LEFT)
					local right_line = config_line(Yatline.config.header_line.right, Side.RIGHT)

					return {
						config_paragraph(self._area, ui.Line({ left_line, left })), -- Styles left_line if show_background set.
						ui.Line({ right, right_line }):area(self._area):align(ui.Align.RIGHT),
					}
				end
			end
		else
			Header.redraw = function()
				return {}
			end
		end

		if Yatline.config.display_status_line then -- Controls displaying status-line.
			if show_line(Yatline.config.status_line) then -- Controls recoding of status-line.
				-- Empties default Yazi status-line.
				Status._left = {}
				Status._right = {}

				Status.redraw = function(self)
					-- Gets Yazi components.
					local left = self:children_redraw(self.LEFT)
					local right = self:children_redraw(self.RIGHT)

					-- Gets Yatline components.
					local right_line = config_line(Yatline.config.status_line.right, Side.RIGHT)
					local sum_right = ui.Line({ right, right_line }) -- Needed for error prevention.

					local result = {}
					local pad = align_pad(self._area, Yatline.config.current_col_align and Yatline.config.current_col_align.status)

					if pad > 9 then
						-- split render: section_a (mode pill) stays at the very left
						-- edge (clipped before the column), sections b+c start at
						-- the current column — same rail as the extra line
						local w = rect_field(self._area, "w") or 0
						local a_area = self._area:pad(ui.Pad.right(w - pad + 1))
						local bc_area = self._area:pad(ui.Pad.left(pad))

						result[#result + 1] = config_paragraph(
							a_area,
							ui.Line({ config_line_sections(Yatline.config.status_line.left, Side.LEFT, { "section_a" }), left })
						)
						result[#result + 1] =
							config_paragraph(bc_area, ui.Line({ config_line_sections(Yatline.config.status_line.left, Side.LEFT, { "section_b", "section_c" }) }))
					else
						local left_line = config_line(Yatline.config.status_line.left, Side.LEFT)
						result[#result + 1] = config_paragraph(self._area, ui.Line({ left_line, left }))
					end

					result[#result + 1] = sum_right:area(self._area):align(ui.Align.RIGHT)
					for _, el in ipairs(ui.redraw(Progress:new(self._area, sum_right:width()))) do
						result[#result + 1] = el
					end
					return result
				end
			end
		else
			Status.redraw = function()
				return {}
			end
		end

		-- Yatline Extra: additional info lines, positions "extra1".."extraN"
		-- (bare "extra" = "extra1") in component_positions.
		-- Plain Lua widget following yazi's preset component pattern (see Modal/Header):
		-- Root:redraw() calls ui.redraw() on every child, so any table with a
		-- redraw() method works as a Root child.
		local function extra_index(component)
			if component == "extra" then
				return 1
			end
			local n = component:match("^extra(%d+)$")
			return n and tonumber(n) or nil
		end

		local function show_extra(n)
			return Yatline.config.display_extra_line
				and Yatline.config.extra_lines[n]
				and show_line(Yatline.config.extra_lines[n])
		end

		local ExtraLine = {
			_id = "yatline-extra",
		}

		function ExtraLine:new(area, index)
			return setmetatable({ _area = area, _index = index }, { __index = self })
		end

		function ExtraLine:reflow()
			return { self }
		end

		function ExtraLine:redraw()
			local cfg = Yatline.config.extra_lines[self._index]
			if not cfg then
				return {}
			end

			local right_line = config_line(cfg.right, Side.RIGHT)
			local elements = {}

			local align_cfg = Yatline.config.current_col_align or {}
			local pad = align_pad(self._area, align_cfg.extra)
			local edge_n = (pad > 0 and tonumber(align_cfg.extra_edge) or 0) or 0

			if pad > 0 then
				local w = rect_field(self._area, "w") or 0

				if edge_n > 0 then
					-- split: sections a/b + first `edge_n` components of left
					-- section_c stay at the very left edge (the parent column);
					-- the rest start at the current column — same rail as status
					local comps = config_section(cfg.left.section_c or {}, ComponentType.C)
					local styled = config_components_separators(comps, ComponentType.C, Side.LEFT, 0, #comps)

					local edge_parts, col_parts = {}, {}
					for i, line in ipairs(styled) do
						if i <= edge_n then
							edge_parts[#edge_parts + 1] = line
						else
							col_parts[#col_parts + 1] = line
						end
					end

					local edge_line = config_line_sections(cfg.left, Side.LEFT, { "section_a", "section_b" })
					local edge_area = self._area:pad(ui.Pad.right(w - pad + 1))
					elements[#elements + 1] =
						config_paragraph(edge_area, ui.Line({ edge_line, table.unpack(edge_parts) }))

					if #col_parts > 0 then
						local col_area = self._area:pad(ui.Pad.left(pad))
						elements[#elements + 1] = config_paragraph(col_area, ui.Line(col_parts))
					end
				else
					local left_line = config_line(cfg.left, Side.LEFT)
					local col_area = self._area:pad(ui.Pad.left(pad))
					elements[#elements + 1] = config_paragraph(col_area, ui.Line({ left_line }))
				end
			else
				local left_line = config_line(cfg.left, Side.LEFT)
				elements[#elements + 1] = config_paragraph(self._area, ui.Line({ left_line }))
			end

			elements[#elements + 1] = ui.Line({ right_line }):area(self._area):align(ui.Align.RIGHT)
			return elements
		end

		-- Mouse events (unused, mirrors Header's empty handlers)
		function ExtraLine:click(event, up) end
		function ExtraLine:scroll(event, step) end
		function ExtraLine:touch(event, step) end

		Root.layout = function(self)
			local constraints = {}
			-- Sets Yazi layout according to the given positions.
			for _, component in ipairs(Yatline.config.component_positions) do
				local en = extra_index(component)
				if
					(component == "header" and Yatline.config.display_header_line)
					or (component == "status" and Yatline.config.display_status_line)
					or (en and show_extra(en))
				then
					table.insert(constraints, ui.Constraint.Length(1))
				elseif component == "tab" then
					table.insert(constraints, ui.Constraint.Fill(1))
				end
			end

			self._chunks = ui.Layout():direction(ui.Layout.VERTICAL):constraints(constraints):split(self._area)
		end

		Root.build = function(self)
			local childrens = {}
			-- Fills the layout according to the given positions.
			local i = 1
			for _, component in ipairs(Yatline.config.component_positions) do
				if component == "header" and Yatline.config.display_header_line then
					table.insert(childrens, Header:new(self._chunks[i], cx.active))
					i = i + 1
				elseif component == "tab" then
					table.insert(childrens, Tab:new(self._chunks[i], cx.active))
					i = i + 1
				elseif component == "status" and Yatline.config.display_status_line then
					table.insert(childrens, Status:new(self._chunks[i], cx.active))
					i = i + 1
				else
					local en = extra_index(component)
					if en and show_extra(en) then
						table.insert(childrens, ExtraLine:new(self._chunks[i], en))
						i = i + 1
					end
				end
			end

			table.insert(childrens, Modal:new(self._area))

			self._children = childrens
		end
	end,
}
