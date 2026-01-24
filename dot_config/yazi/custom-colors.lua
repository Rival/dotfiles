-- Get current time for comparison
local function get_current_time()
	return os.time()
end

-- Check if file was modified recently (within specified hours)
local function is_recently_modified(file, hours)
	if not file or not file.cha then
		return false
	end
	
	local current_time = get_current_time()
	local modified_time = file.cha.modified
	
	if not modified_time then
		return false
	end
	
	local time_diff = current_time - modified_time
	local hours_diff = time_diff / 3600
	
	return hours_diff <= hours
end

-- Override the Entity:highlight method
function Entity:highlight()
	local color = nil
	
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
		ui.Span(" "),
		ui.Span(icon.text):style(icon.style),
		ui.Span(" " .. self._file:name()):style(THEME.manager[color] or {}),
	}
end
