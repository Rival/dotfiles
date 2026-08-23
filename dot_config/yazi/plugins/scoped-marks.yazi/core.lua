-- scoped-marks: чистое ядро без Yazi-глобалов (исполняется под обычным Lua 5.5).
-- Отвечает за: нормализацию путей, строгую валидацию schema-v1 документов,
-- валидацию конфига маркеров, построение индексов exact/below, шаблоны
-- маркеров, стабильное разбиение и иммутабельные upsert/remove.
-- Дизайн: ~/.config/yazi/docs/scoped-marks-design.md (rev4.1).

local lang = require(".lang")

local M = {}

local DEFAULTS = {
	marker = {
		enabled = true,
		slot = "name",
		order = nil, -- nil: default 4500 для "name", 1500 для "linemode"
		leaf = "★",
		branch = "▾{n}",
		both = "★{n}",
		separator = " ",
		fg = "yellow",
		bold = true,
	},
	reload_on_cd = true,
	menu = {
		style = "pick",
		quick_jump = true,
		cursor_bg = nil,
		cursor_fg = "black",
		quick_pool = nil,
		group_threshold = 5,
		empty_scope = "all",
		lang = "ru",
	},
}

-- Дефолты конфига (§5). Экспортированы read-only для потребителей main.lua
-- (pre-setup фоллбек опций меню); валидация НИКОГДА не мутирует эти таблицы
-- — каждая валидация строит свежие таблицы (см. validate_config).
M.DEFAULTS = DEFAULTS

-- ── нормализация путей ─────────────────────────────────────────────────────

-- Строгая лексическая форма: абсолютный путь без "//", ".", "..",
-- с не более чем одним хвостовым "/" (у корня "/" остаётся).
-- Возвращает (normalized) или (nil, error_string).
function M.normalize_path(raw)
	if type(raw) ~= "string" then
		return nil, "путь должен быть строкой"
	end
	if #raw == 0 or raw:sub(1, 1) ~= "/" then
		return nil, "путь должен быть абсолютным"
	end
	-- Повторные разделители отвергаем ДО обрезки хвостового слэша.
	if raw:find("//", 1, true) then
		return nil, "повторяющиеся разделители «//»"
	end
	local path = raw
	if #path > 1 and path:sub(-1) == "/" then
		path = path:sub(1, -2)
	end
	for component in path:gmatch("[^/]+") do
		if component == "." or component == ".." then
			return nil, ("компонент «%s» не допускается"):format(component)
		end
	end
	return path
end

-- ── валидация документа ────────────────────────────────────────────────────

-- doc: { version = 1, bookmarks = JSON-массив записей { path, label } }.
-- is_json_array(value): pinned-хелпер, отличающий массив (в т.ч. пустой [])
-- от объекта {}. url_check(path): Yazi-интеграционная проверка
-- Url.is_regular/is_absolute и строкового round-trip.
-- Возвращает свежий массив { path = normalized, label = string } или
-- (nil, error_string). Дубликаты по нормализованному пути — ошибка.
function M.validate_document(doc, is_json_array, url_check)
	if type(doc) ~= "table" then
		return nil, "документ должен быть таблицей"
	end
	if doc.version ~= 1 then
		return nil, "version должен быть равен 1"
	end
	if not is_json_array(doc.bookmarks) then
		return nil, "bookmarks должен быть JSON-массивом"
	end

	local records, seen = {}, {}
	for index, record in ipairs(doc.bookmarks) do
		if type(record) ~= "table" then
			return nil, ("запись %d должна быть таблицей"):format(index)
		end
		local normalized, path_error = M.normalize_path(record.path)
		if not normalized then
			return nil, ("запись %d: %s"):format(index, path_error)
		end
		if type(record.label) ~= "string" then
			return nil, ("запись %d: label должен быть строкой"):format(index)
		end
		if seen[normalized] then
			return nil, ("дубликат пути после нормализации: %s"):format(normalized)
		end
		if url_check(normalized) ~= true then
			return nil, ("путь не прошёл URL-проверку: %s"):format(normalized)
		end
		seen[normalized] = true
		records[#records + 1] = { path = normalized, label = record.label }
	end
	return records
end

-- ── валидация конфига маркеров ─────────────────────────────────────────────

local SLOT_DEFAULT_ORDER = { name = 4500, linemode = 1500 }

local function is_finite_number(value)
	if type(value) ~= "number" then
		return false
	end
	if value ~= value then -- NaN
		return false
	end
	return math.abs(value) ~= math.huge
end

local function is_exact_boolean(value)
	return type(value) == "boolean"
end

-- Валидация меню (§5): style ∈ { pick, which } (default pick), quick_jump —
-- точный boolean (default true), cursor_bg — nil или цвет (bg_check-коллбек
-- по аналогии с fg маркера), quick_pool — nil или непустая строка символов
-- под раскладку пользователя (зарезервированные j/k/q пропускаются при
-- раздаче клавиш в main.lua — это не ошибка конфига);
-- field-level fallback с одним warning на поле.
local function validate_menu(raw, warnings, bg_check, fg_check, L)
	local menu = raw.menu
	if menu == nil then
		menu = {}
	elseif type(menu) ~= "table" then
		warnings[#warnings + 1] = L.w_menu_table
		menu = {}
	end

	local config = {
		style = DEFAULTS.menu.style,
		quick_jump = DEFAULTS.menu.quick_jump,
		cursor_bg = DEFAULTS.menu.cursor_bg,
		cursor_fg = DEFAULTS.menu.cursor_fg,
		quick_pool = DEFAULTS.menu.quick_pool,
		group_threshold = DEFAULTS.menu.group_threshold,
		empty_scope = DEFAULTS.menu.empty_scope,
		lang = DEFAULTS.menu.lang,
	}
	if menu.style ~= nil then
		if menu.style == "pick" or menu.style == "which" then
			config.style = menu.style
		else
			warnings[#warnings + 1] = L.w_menu_style
		end
	end
	if menu.quick_jump ~= nil then
		if is_exact_boolean(menu.quick_jump) then
			config.quick_jump = menu.quick_jump
		else
			warnings[#warnings + 1] = L.w_menu_quick_jump
		end
	end
	if menu.cursor_bg ~= nil then
		if bg_check(menu.cursor_bg) then
			config.cursor_bg = menu.cursor_bg
		else
			warnings[#warnings + 1] = L.w_menu_cursor_bg
		end
	end
	-- cursor_fg применяется ТОЛЬКО вместе с cursor_bg (контрастный текст на
	-- беке); проверяется fg_check-ом как цвет маркера.
	if menu.cursor_fg ~= nil then
		if fg_check(menu.cursor_fg) then
			config.cursor_fg = menu.cursor_fg
		else
			warnings[#warnings + 1] = L.w_menu_cursor_fg
		end
	end
	if menu.quick_pool ~= nil then
		if type(menu.quick_pool) == "string" and #menu.quick_pool > 0 then
			config.quick_pool = menu.quick_pool
		else
			warnings[#warnings + 1] = L.w_menu_quick_pool
		end
	end
	-- Порог древовидности (§9b): записей больше порога — группировка по
	-- общему префиксу, меньше/равно — плоский список. 0 = никогда.
	if menu.group_threshold ~= nil then
		if type(menu.group_threshold) == "number"
			and menu.group_threshold >= 0
			and menu.group_threshold % 1 == 0
		then
			config.group_threshold = menu.group_threshold
		else
			warnings[#warnings + 1] = L.w_menu_group_threshold
		end
	end
	-- Поведение ' при пустом scoped-блоке (§9c): "all" — сразу все закладки,
	-- "message" — пункт-сообщение в меню (g оттуда покажет все).
	if menu.empty_scope ~= nil then
		if menu.empty_scope == "all" or menu.empty_scope == "message" then
			config.empty_scope = menu.empty_scope
		else
			warnings[#warnings + 1] = L.w_menu_empty_scope
		end
	end
	-- Локаль строк (§9c); валидна — применяется и к своим же варнингам.
	if menu.lang ~= nil then
		if lang.locales[menu.lang] then
			config.lang = menu.lang
		else
			warnings[#warnings + 1] = L.w_menu_lang
		end
	end
	return config
end

-- raw: пользовательская таблица из scoped-marks.lua (может быть nil).
-- fg_check(value) -> boolean: проверка значения под pcall на стороне Yazi.
-- bg_check — опциональный аналог для cursor_bg (nil → используется fg_check).
-- Возвращает (config, warnings): field-level fallback, отсутствующие поля
-- молча берут default, некорректные присутствующие дают по одному warning.
function M.validate_config(raw, fg_check, bg_check)
	local warnings = {}
	local L = lang.get(raw ~= nil and type(raw) == "table" and raw.menu ~= nil
		and type(raw.menu) == "table" and raw.menu.lang or nil)
	local config = {
		marker = {},
		reload_on_cd = DEFAULTS.reload_on_cd,
	}

	if raw == nil then
		raw = {}
	elseif type(raw) ~= "table" then
		warnings[#warnings + 1] = L.w_config
		raw = {}
	end
	if bg_check == nil then
		bg_check = fg_check
	end

	local marker = raw.marker
	if marker == nil then
		marker = {}
	elseif type(marker) ~= "table" then
		warnings[#warnings + 1] = L.w_marker_table
		marker = {}
	end

	local m = config.marker
	m.enabled = DEFAULTS.marker.enabled
	if marker.enabled ~= nil then
		if is_exact_boolean(marker.enabled) then
			m.enabled = marker.enabled
		else
			warnings[#warnings + 1] = L.w_marker_enabled
		end
	end

	m.slot = DEFAULTS.marker.slot
	if marker.slot ~= nil then
		if marker.slot == "name" or marker.slot == "linemode" then
			m.slot = marker.slot
		else
			warnings[#warnings + 1] = L.w_marker_slot
		end
	end

	-- order валидируется после slot: default зависит от слота.
	if marker.order == nil then
		m.order = SLOT_DEFAULT_ORDER[m.slot]
	elseif is_finite_number(marker.order) then
		m.order = marker.order
	else
		warnings[#warnings + 1] = L.w_marker_order
		m.order = SLOT_DEFAULT_ORDER[m.slot]
	end

	for _, field in ipairs({ "leaf", "branch", "both", "separator" }) do
		m[field] = DEFAULTS.marker[field]
		if marker[field] ~= nil then
			if type(marker[field]) == "string" then
				m[field] = marker[field]
			else
				warnings[#warnings + 1] = L.w_marker_field:format(field)
			end
		end
	end

	m.fg = DEFAULTS.marker.fg
	if marker.fg ~= nil then
		if fg_check and fg_check(marker.fg) then
			m.fg = marker.fg
		else
			warnings[#warnings + 1] = L.w_marker_fg
		end
	end

	m.bold = DEFAULTS.marker.bold
	if marker.bold ~= nil then
		if is_exact_boolean(marker.bold) then
			m.bold = marker.bold
		else
			warnings[#warnings + 1] = L.w_marker_bold
		end
	end

	if raw.reload_on_cd ~= nil then
		if is_exact_boolean(raw.reload_on_cd) then
			config.reload_on_cd = raw.reload_on_cd
		else
			warnings[#warnings + 1] = L.w_reload_on_cd
		end
	end

	config.menu = validate_menu(raw, warnings, bg_check, fg_check, L)

	return config, warnings
end

-- ── индексы ────────────────────────────────────────────────────────────────

-- exact[path] = true для каждой закладки.
-- below[strict-ancestor] = число строгих лексических потомков-закладок.
-- Закладка не считает саму себя; корень "/" завершает цикл родителей.
function M.build_indexes(bookmarks)
	local exact, below = {}, {}
	for _, record in ipairs(bookmarks) do
		local path = record.path
		exact[path] = true
		local parent = path
		while parent ~= "/" do
			parent = parent:match("^(.*)/[^/]+$") or "/"
			if parent == "" then
				parent = "/"
			end
			below[parent] = (below[parent] or 0) + 1
		end
	end
	return exact, below
end

-- ── шаблон маркера ─────────────────────────────────────────────────────────

-- Возвращает текст маркера БЕЗ разделителя: "" — нет маркера, иначе шаблон
-- с подстановкой {n} = числу строгих потомков-закладок (включая 0).
function M.marker_text(marker_config, is_exact, below_count)
	local template
	if is_exact then
		if below_count ~= nil and below_count > 0 then
			template = marker_config.both
		else
			template = marker_config.leaf
		end
	elseif below_count ~= nil and below_count > 0 then
		template = marker_config.branch
	else
		return ""
	end
	return (template:gsub("{n}", tostring(below_count or 0)))
end

-- ── стабильное разбиение ───────────────────────────────────────────────────

-- Делит записи на in_scope/global, сохраняя исходный порядок в каждой части.
function M.partition(bookmarks, in_scope_predicate)
	local in_scope, global = {}, {}
	for _, record in ipairs(bookmarks) do
		if in_scope_predicate(record) then
			in_scope[#in_scope + 1] = record
		else
			global[#global + 1] = record
		end
	end
	return in_scope, global
end

-- ── иммутабельные мутации ──────────────────────────────────────────────────

-- Обновляет label существующего пути на месте (позиция сохраняется) или
-- добавляет новую запись в конец. Возвращает (новый_массив, was_update).
function M.upsert(bookmarks, normalized_path, label)
	local out = {}
	local was_update = false
	for index, record in ipairs(bookmarks) do
		if record.path == normalized_path then
			out[index] = { path = normalized_path, label = label }
			was_update = true
		else
			out[index] = { path = record.path, label = record.label }
		end
	end
	if not was_update then
		out[#out + 1] = { path = normalized_path, label = label }
	end
	return out, was_update
end

-- Удаляет запись с путём, сохраняя порядок остальных. Возвращает
-- (новый_массив, found); при удалении последней записи массив пуст.
function M.remove(bookmarks, normalized_path)
	local out = {}
	local found = false
	for _, record in ipairs(bookmarks) do
		if record.path == normalized_path then
			found = true
		else
			out[#out + 1] = { path = record.path, label = record.label }
		end
	end
	return out, found
end

return M
