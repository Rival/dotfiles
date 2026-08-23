-- scoped-marks menu.lua: ЧИСТЫЕ билдеры pick-оверлея закладок.
-- Никакого I/O, notify, emit, render и мутаций состояния: геометрия,
-- навигационные кандидаты и ui-элементы строятся из plain-данных.
-- Глобалы Yazi (ui) используются только ВНУТРИ функций, поэтому модуль
-- грузится и тестируется обычным Lua (dofile) без рантайма.
-- Дизайн: ~/.config/yazi/docs/scoped-marks-design.md (rev4.3 §9a).
--
-- Пин API Yazi 26.5.6 (commit aa526434):
--  - Modal:children_add (PR #2205): компонент-таблица с _id/new/reflow/redraw,
--    Modal получает ПОЛНЫЙ Rect терминала (root.rs → Modal:new(self._area)).
--  - ya.which{ silent=true }: ничего не рисует (which.rs: ранний return),
--    возвращает 1-based индекс нажатого кандидата либо nil. При дубликатах
--    on-клавиш побеждает ПЕРВЫЙ полностью совпавший кандидат
--    (which/which.rs: retain + position(|c| c.on.len() == times)) — поэтому
--    пул quick-клавишь пропускает зарезервированные j/k/q.
--    Спец-клавиши в cands.on ОБЯЗАНЫ быть в угловых скобках: Key::from_str
--    без «<…>» вырождает строку в первый символ (keymap/key.rs: "up" →
--    Char('u'), "end"/"enter"/"esc" → Char('e')); имени "escape" не
--    существует — только "esc".
--  - th.pick.{border,active,inactive} — в реальном Yazi это Style,
--    доступные через Composer-USERDATA (theme/theme.rs, type()=="userdata",
--    НЕ table); в harness — обычные таблицы. Читаются через pcall-гварды.
--  - Размещение зеркалит нативный pick (popup/position.rs::sticky):
--    ниже якоря, когда влезает, иначе сверху, с клампом в Rect терминала.
--
-- Грузится из main.lua ТОЛЬКО через yazi runtime require(".menu"):
-- относительный dofile резолвится от CWD процесса, а не от каталога плагина.

local M = {}

M.TITLE = "Закладки"

-- Неселектируемая строка-разделитель между scoped- и global-блоками.
-- Копируется при построении строк (main.lua переносит ТОЛЬКО kind);
-- селектируемость определяется kind ~= "separator".
M.SEPARATOR_ROW = { kind = "separator" }

-- Клавиши-модификаторы навигации: зарезервированы и никогда не выдаются
-- как quick-jump (см. шапку: дубликат on-клавиши убил бы quick-прыжок);
-- g — тоггл «все закладки» (§9b).
local RESERVED_NAV_KEYS = { j = true, k = true, q = true, g = true }

-- Спец-имена ТОЛЬКО в <...> (см. шапку: голое имя вырождается в первый
-- символ и никогда не совпадёт с реальной стрелкой/Esc); j/k/q/g — обычные
-- символы, скобки не нужны (и не допускаются для одиночных клавиш).
-- <right>/<left> — вход в группу / уровень выше (древовидный режим §9b).
local NAV_KEYS = {
	"<up>", "k", "<down>", "j", "<home>", "<end>", "<enter>", "<esc>", "q", "<right>", "<left>", "g",
}
local NAV_KINDS = {
	"up", "up", "down", "down", "home", "end", "select", "close", "close", "enter", "back", "toggle_all",
}

-- ── ширина и усечение ──────────────────────────────────────────────────────

-- Число codepoint'ов валидного UTF-8 (считаем ведущие байты). Приближение
-- display-ширины: для меток из путей/кириллицы codepoint == колонка.
local function cp_len(s)
	local _, n = s:gsub("[^\128-\191]", "")
	return n
end

-- Однострочное усечение с хвостовым «…»: результат занимает не больше w
-- codepoint'ов. w <= 0 → "", w == 1 → «…».
function M.truncate_line(s, w)
	if w == nil or w <= 0 then
		return ""
	end
	if cp_len(s) <= w then
		return s
	end
	if w == 1 then
		return "…"
	end
	local cut = utf8.offset(s, w) -- байтовое смещение codepoint'а №w
	return s:sub(1, cut - 1) .. "…"
end

-- ── древовидная группировка (§9b) ─────────────────────────────────────────────

-- Суффикс пути относительно базы (base == "" → весь путь с "/").
local function suffix_of(path, base)
	if base == "" then
		return path
	end
	return path:sub(#base + 2) -- base без хвостового "/"
end

local function join_base(base, comp)
	if base == "" then
		return "/" .. comp
	end
	return base .. "/" .. comp
end

-- Бакетирование по СЛЕДУЮЩЕМУ компоненту после base: возвращает
-- order (список головных компонент в порядке вставки = алфавит, т.к.
-- записи отсортированы) и buckets[head] = записи. Запись, чей путь РАВЕН
-- base, попадает в self_leaf (закладка на самой папке группы).
local function bucketize(records, base)
	local order, buckets, self_leaf = {}, {}, nil
	for _, r in ipairs(records) do
		if r.path == base then
			self_leaf = r
		else
			local rel = base == "" and r.path:sub(2) or r.path:sub(#base + 2)
			local head = rel:match("^[^/]+")
			if buckets[head] == nil then
				order[#order + 1] = head
				buckets[head] = {}
		end
			buckets[head][#buckets[head] + 1] = r
		end
	end
	return order, buckets, self_leaf
end

-- Сжатие одиночной цепочки: группа с единственной подгруппой и без
-- self-листа склеивается (mnt/Intel2TB/Emulation — один узел, не три).
-- Возвращает узел уровня:
--   leaf:  { kind="leaf",  record, name }         — name = суффикс от базы уровня
--   group: { kind="group", name, count, records, base } — base = ПОЛНЫЙ путь группы
local function compress(records, base, name, threshold)
	while true do
		if #records == 1 then
			-- одиночная запись: лист до конца цепочки (группа из одного листа
			-- внутри — бессмысленный лишний уровень)
			local r = records[1]
			return {
				kind = "leaf",
				record = r,
				name = r.path == base and name or (name .. "/" .. suffix_of(r.path, base)),
			}
		end
		if #records <= threshold then
			return { kind = "group", name = name, count = #records, records = records, base = base }
		end
		local order, buckets, self_leaf = bucketize(records, base)
		if self_leaf ~= nil or #order ~= 1 then
			return { kind = "group", name = name, count = #records, records = records, base = base }
		end
		local head = order[1]
		name = name .. "/" .. head
		base = join_base(base, head)
		records = buckets[head]
	end
end

-- Узлы уровня для списка записей под базой. ≤ threshold — плоские листья
-- (на корне это полные пути, на подуровне — короткие суффиксы; запись на
-- самой базе — имя "."); > threshold — бакеты, каждый сжат в один узел.
-- threshold ≤ 0 нельзя передавать (за этим следит main: древовидность
-- выключена). Записи вне базы — UB (main гарантирует принадлежность).
function M.nodes_for(records, base, threshold)
	base = base or ""
	if #records <= threshold then
		local out = {}
		for _, r in ipairs(records) do
			out[#out + 1] = {
				kind = "leaf",
				record = r,
				name = r.path == base and "." or suffix_of(r.path, base),
			}
		end
		return out
	end
	local order, buckets, self_leaf = bucketize(records, base)
	local out = {}
	if self_leaf ~= nil then
			out[1] = { kind = "leaf", record = self_leaf, name = "." }
		end
	for _, head in ipairs(order) do
			out[#out + 1] = compress(buckets[head], join_base(base, head), head, threshold)
		end
	return out
end

-- ── геометрия ──────────────────────────────────────────────────────────────

-- (anchor_row, anchor_col): экранная позиция hover-строки; rows: список строк
-- меню (нужен widest и count); term_w/term_h: полный терминал (Modal._area).
-- Возвращает Rect { x, y, w, h }: ширина = widest + 2 (паддинг), высота =
-- min(term_h - 2, border 2 + rows) и не меньше 3 (модель нативного pick:
-- margin по одной строке сверху/снизу); бокс ниже якоря, иначе сверху,
-- с клампом в границы терминала (popup/position.rs::sticky).
function M.geometry(anchor_row, anchor_col, rows, term_w, term_h, title)
	term_w = math.max(1, math.floor(term_w or 1))
	term_h = math.max(1, math.floor(term_h or 1))
	rows = rows or {}

	local widest = cp_len(title or M.TITLE)
	for _, row in ipairs(rows) do
		if row.kind ~= "separator" then
			local n = cp_len(row.line or "")
			if n > widest then
				widest = n
			end
		end
	end
	local w = math.min(widest + 2, term_w)

	local cap = term_h - 2
	local h = math.min(cap, #rows + 2)
	h = math.max(3, h)
	h = math.min(h, term_h)

	local anchor = math.floor(anchor_row or 0)
	local y = anchor + 1 -- ниже якоря
	if y + h > term_h then
		y = anchor - h -- сверху от якоря
	end
	y = math.max(0, math.min(y, term_h - h))
	local x = math.max(0, math.min(math.floor(anchor_col or 0), term_w - w))
	return { x = x, y = y, w = w, h = h }
end

-- ── навигация ──────────────────────────────────────────────────────────────

-- Quick-клавиша ordinal-й селектируемой строки: символы пула по порядку,
-- ПРОПУСКАЯ зарезервированные j/k/q (коллизия с up/down/close навигацией;
-- полный 62-символьный пул даёт 59 клавиш). nil — пул исчерпан.
function M.quick_key(ordinal, pool)
	if type(pool) ~= "string" or type(ordinal) ~= "number" or ordinal < 1 then
		return nil
	end
	local seen = 0
	for ch in pool:gmatch(".") do
		if not RESERVED_NAV_KEYS[ch] then
			seen = seen + 1
			if seen == ordinal then
				return ch
			end
		end
	end
	return nil
end

-- Кандидаты для silent ya.which + resolve(index) → действие:
--   "up"|"down"|"home"|"end"|"select"|"close" либо { jump = n } (n —
--   1-based номер селектируемой строки). nil/неизвестный индекс → "close".
-- Возвращает { cands = список { on, desc = "" }, resolve = fn } (карта
-- jumps — внутренняя, для resolve).
function M.nav_cands(selectable_count, quick, pool)
	local cands = {}
	for i = 1, #NAV_KEYS do
		cands[i] = { on = NAV_KEYS[i], desc = "" }
	end
	local jumps = {}
	if quick then
		for ordinal = 1, selectable_count do
			local key = M.quick_key(ordinal, pool)
			if key == nil then
				break
			end
			jumps[ordinal] = key
			cands[#cands + 1] = { on = key, desc = "" }
		end
	end
	local base = #NAV_KEYS
	local function resolve(index)
		if type(index) ~= "number" or index < 1 or index > #cands or index > base and jumps[index - base] == nil then
			return "close"
		end
		if index <= base then
			return NAV_KINDS[index]
		end
		return { jump = index - base }
	end
	return { cands = cands, resolve = resolve }
end

-- Число селектируемых строк (разделитель и message-пункт не считаются).
function M.selectable_count(rows)
	local n = 0
	for _, row in ipairs(rows or {}) do
		if row.kind ~= "separator" and row.kind ~= "message" then
			n = n + 1
		end
	end
	return n
end

-- Курсор с зацикливанием по селектируемым строкам (cursor/delta — 1-based).
function M.move_cursor(rows, cursor, delta)
	local n = M.selectable_count(rows)
	if n == 0 then
		return 1
	end
	return ((cursor - 1 + delta) % n) + 1
end

-- Строка с jump == заданному (селектируемая), либо nil.
function M.row_by_jump(rows, jump)
	for _, row in ipairs(rows or {}) do
		if row.jump == jump then
			return row
		end
	end
	return nil
end

-- ── ui-элементы ────────────────────────────────────────────────────────────

-- rows == nil → {} (закрытое меню — константное время). Иначе:
--   [1] ui.Clear(rect), [2] ui.Border(ALL) с заголовком M.TITLE и
--   th.pick.border, далее строки внутри рамки: курсорная — theme.active,
--   остальные и разделитель — theme.inactive. Длинные строки усечены до
--   внутренней ширины; если строки не влезают по высоте, показывается окно,
--   центрированное вокруг курсора (нативный pick держит выбор видимым).
-- theme = { border = …, active = …, inactive = … }; nil-поля → без стиля.
function M.elements(rows, cursor, geo, theme, title)
	if rows == nil then
		return {}
	end
	theme = theme or {}
	local rect = ui.Rect { x = geo.x, y = geo.y, w = geo.w, h = geo.h }
	local out = { ui.Clear(rect) }

	local border = ui.Border(ui.Edge.ALL):area(rect):title(ui.Line(title or M.TITLE))
	if theme.border ~= nil then
		border = border:style(theme.border)
	end
	out[#out + 1] = border

	local inner_w = geo.w - 2
	local inner_h = geo.h - 2
	if inner_w <= 0 or inner_h <= 0 then
		return out
	end

	local cursor_row_index = 1
	for i, row in ipairs(rows) do
		if row.jump == cursor then
			cursor_row_index = i
			break
		end
	end
	local start = 1
	if #rows > inner_h then
		local centered = cursor_row_index - math.floor((inner_h - 1) / 2)
		start = math.max(1, math.min(centered, #rows - inner_h + 1))
	end

	local shown = 0
	for i = start, #rows do
		if shown >= inner_h then
			break
		end
		local row = rows[i]
		local text, style
		if row.kind == "separator" then
			text = ("─"):rep(inner_w)
			style = theme.inactive
		else
			text = M.truncate_line(row.line or "", inner_w)
			style = (row.jump == cursor) and theme.active or theme.inactive
		end
		local line = ui.Line(text):area(ui.Rect {
			x = geo.x + 1,
			y = geo.y + 1 + shown,
			w = inner_w,
			h = 1,
		})
		if style ~= nil then
			line = line:style(style)
		end
		out[#out + 1] = line
		shown = shown + 1
	end
	return out
end

return M
