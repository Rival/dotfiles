-- scoped-marks: рантайм-закладки с нативным меню, O(1) маркерами строк,
-- JSON-состоянием и мгновенной синхронизацией процессов.
-- Единственный источник истины: $XDG_STATE_HOME/yazi/scoped-marks/bookmarks.json
-- (schema v1). bookmarks.lua больше не читается.
-- Дизайн: ~/.config/yazi/docs/scoped-marks-design.md (rev4.1).
-- Пин API Yazi 26.5.6 / Lua 5.5.1: ya.json_encode/decode (source-confirmed),
-- ps.pub_to(0)/ps.sub_remote, Entity/Linemode children_add, ya.async.
-- Локальный форк вне `ya pkg` → переживает `ya pkg upgrade`.

-- Сibling-модули грузятся через yazi runtime require: dot-префикс резолвится
-- в текущий plugin-frame ("scoped-marks.core") — так же, как mount.yazi грузит
-- .cross. НЕ dofile("./core.lua"): относительный dofile резолвится от CWD
-- процесса yazi, а не от каталога плагина.
local core = require(".core")
local menu_mod = require(".menu") -- чистые билдеры pick-оверлея (§9a)
local lang_mod = require(".lang") -- локализация строк (§9c)
local L = lang_mod.get(nil) -- актуальная локаль; setup() обновит по конфигу

local EVENT = "scoped-marks-changed"
local KEY_POOL = "asdfghjklqwertyuiopzxcvbnm1234567890ASDFGHJKLQWERTYUIOPZXCVBNM"
local APP_ID = ya.id("app").value

-- ── разрешение пути состояния ──────────────────────────────────────────────

-- (dir, target) либо (nil, error). XDG_STATE_HOME учитывается только
-- абсолютным; иначе $HOME/.local/state; иначе ошибка.
local function state_paths()
	local base = os.getenv("XDG_STATE_HOME")
	if type(base) ~= "string" or base == "" or base:sub(1, 1) ~= "/" then
		local home = os.getenv("HOME")
		if type(home) ~= "string" or home == "" then
			return nil, L.xdg_missing
		end
		base = home .. "/.local/state"
	end
	local dir = base .. "/yazi/scoped-marks"
	return dir, dir .. "/bookmarks.json"
end

-- ── JSON-хелперы и валидация ───────────────────────────────────────────────

-- Pinned-проверка массивной идентичности для НЕПУСТЫХ таблиц: повторное
-- кодирование значения должно начинаться с "[" (mlua сериализует непустые
-- последовательности 1..n как массивы).
local function json_is_array(value)
	local encoded = ya.json_encode(value)
	return type(encoded) == "string" and encoded:sub(1, 1) == "["
end

-- Пустую таблицу так отличить от объекта НЕЛЬЗЯ: pinned-исходник Yazi 26.5.6
-- показывает, что mlua 0.11.6 исполняется БЕЗ array_metatable (SER_OPT его
-- не задаёт), поэтому ya.json_decode("[]") возвращает обычную пустую {},
-- а ya.json_encode({}) даёт "{}". Единственное доказательство того, что
-- пустой bookmarks был JSON-массивом, — буквальные байты источника.
local function bytes_has_bookmarks_array(text)
	return type(text) == "string" and text:find('"bookmarks"%s*:%s*%[', 1) ~= nil
end

-- Колбэк is_json_array для core.validate_document: полностью пустая таблица
-- (возможный декод и "[]", и "{}") признаётся массивом только по байтам
-- источника; непустые значения — прежней re-encode проверкой.
local function array_validator(bytes)
	return function(value)
		if type(value) == "table" and next(value) == nil then
			return bytes_has_bookmarks_array(bytes)
		end
		return json_is_array(value)
	end
end

-- Yazi-интеграционная URL-проверка: обычный абсолютный локальный путь,
-- строковый round-trip которого совпадает с входом.
local function url_check(path)
	local url = Url(path)
	return url.is_regular and url.is_absolute and tostring(url) == path
end

-- Чтение канонического файла. Возвращает:
--   (records, nil) — валидированный список (возможно пустой);
--   (nil, error)   — держим last-good у вызывающего.
-- Только numeric errno == 2 (ENOENT) считается валидным пустым документом.
local function read_canonical(target)
	local file, message, errno = io.open(target, "rb")
	if not file then
		if type(errno) == "number" and errno == 2 then
			return {}, nil
		end
		return nil, L.read_err:format(target, tostring(message))
	end
	local bytes = file:read("a")
	local close_ok = file:close()
	if bytes == nil or not close_ok then
		return nil, L.read_stream:format(target)
	end
	if #bytes == 0 then
		return nil, L.read_empty:format(target)
	end
	local doc, decode_err = ya.json_decode(bytes)
	if doc == nil then
		return nil, L.read_json:format(target, tostring(decode_err))
	end
	local records, validate_err = core.validate_document(doc, array_validator(bytes), url_check)
	if records == nil then
		return nil, L.read_schema:format(target, validate_err)
	end
	return records, nil
end

-- ── sync-мосты (top-level ya.sync) ─────────────────────────────────────────

local reserve_reload = ya.sync(function(st)
	st.latest_epoch = (st.latest_epoch or 0) + 1
	return st.latest_epoch
end)

local apply_reload = ya.sync(function(st, epoch, bookmarks)
	if epoch ~= st.latest_epoch then
		return false
	end
	local exact, below = core.build_indexes(bookmarks)
	st.bookmarks, st.exact, st.below = bookmarks, exact, below
	ui.render()
	return true
end)

local next_temp_seq = ya.sync(function(st)
	st.temp_seq = (st.temp_seq or 0) + 1
	return st.temp_seq
end)

local get_cwd = ya.sync(function(st)
	return cx.active.current.cwd
end)

local get_bookmarks = ya.sync(function(st)
	return st.bookmarks
end)

local get_config = ya.sync(function(st)
	return st.config
end)

-- ── sync-мосты pick-меню (top-level ya.sync, §9a) ─────────────────────────
-- Каждый вызов рендерится (sync-действие/активация ya.which); мутации ТОЛЬКО
-- st.menu: { rows = снапшот строк на момент открытия, cursor = 1-based
-- индекс по селектируемым строкам }.

local menu_open = ya.sync(function(st, rows, title)
	st.menu = { rows = rows, cursor = 1, title = title }
end)

local menu_close = ya.sync(function(st)
	st.menu = nil
end)

local menu_move = ya.sync(function(st, cursor)
	if st.menu ~= nil then
		st.menu.cursor = cursor
	end
end)

local menu_is_open = ya.sync(function(st)
	return st.menu ~= nil
end)

-- DDS-публикация отдельным защищённым шагом: сбой не откатывает коммит.
local publish_dds = ya.sync(function(st)
	local ok, err = pcall(ps.pub_to, 0, EVENT, { origin = APP_ID })
	if not ok then
		return false, err
	end
	return true
end)

-- ── канонический reload ────────────────────────────────────────────────────

-- Резервирует эпоху, читает/валидирует канонический JSON и публикует
-- snapshot ТОЛЬКО через apply_reload. Никогда не публикует DDS.
local function reload_canonical()
	local dir, target = state_paths()
	if not dir then
		ya.notify({ title = "scoped-marks", content = target, timeout = 5 })
		return false, target
	end
	local epoch = reserve_reload()
	local records, err = read_canonical(target)
	if records == nil then
		ya.notify({ title = "scoped-marks", content = err, timeout = 5 })
		return false, err
	end
	local applied = apply_reload(epoch, records)
	return applied, applied and nil or "reload устарел"
end

-- ── атомарная персистентность ──────────────────────────────────────────────

-- Записывает schema-v1 документ через sibling temp → rename.
-- Перед записью байты проходят encode → decode → строгую валидацию.
-- Возвращает (true, nil) либо (false, error) без изменения канонического файла.
local function persist(bookmarks)
	local dir, target = state_paths()
	if not dir then
		return false, target
	end

	local seq = next_temp_seq()

	local ok_create, create_err = fs.create("dir_all", Url(dir))
	if ok_create ~= true then
		return false, ("fs.create: %s"):format(tostring(create_err))
	end

	-- Пустой список пишем детерминированными буквальными байтами: под mlua
	-- 0.11.6 без array_metatable пустая Lua-таблица кодируется как "{}", так
	-- что получить [] кодированием таблицы невозможно (причина — у
	-- bytes_has_bookmarks_array).
	local encoded
	if #bookmarks == 0 then
		encoded = '{"version":1,"bookmarks":[]}'
	else
		local document = { version = 1, bookmarks = bookmarks }
		local encoded_value, encode_err = ya.json_encode(document)
		if encoded_value == nil then
			return false, ("json_encode: %s"):format(tostring(encode_err))
		end
		encoded = encoded_value
	end

	-- Round-trip: декодируем собственные байты (включая буквальные байты
	-- пустого документа) и валидируем тем же путём, что и чтение, до записи.
	local decoded, decode_err = ya.json_decode(encoded)
	if decoded == nil then
		return false, ("round-trip json_decode: %s"):format(tostring(decode_err))
	end
	local verified, verify_err = core.validate_document(decoded, array_validator(encoded), url_check)
	if verified == nil then
		return false, ("round-trip схема: %s"):format(verify_err)
	end

	local temp = ("%s/bookmarks.json.tmp.%d.%d"):format(dir, APP_ID, seq)

	local ok_write, write_err = fs.write(Url(temp), encoded .. "\n")
	if ok_write ~= true then
		pcall(fs.remove, "file", Url(temp))
		return false, ("fs.write: %s"):format(tostring(write_err))
	end

	local ok_rename, rename_err = fs.rename(Url(temp), Url(target))
	if ok_rename ~= true then
		pcall(fs.remove, "file", Url(temp))
		return false, ("fs.rename: %s"):format(tostring(rename_err))
	end

	return true, nil
end

-- ── вспомогательные действия ───────────────────────────────────────────────

local function notify(content)
	ya.notify({ title = "scoped-marks", content = content, timeout = 4 })
end

-- Нормализованный путь обычной абсолютной локальной cwd либо nil (VFS/поиск).
local function current_cwd_path()
	local cwd_url = get_cwd()
	if not cwd_url or not cwd_url.is_regular or not cwd_url.is_absolute then
		return nil
	end
	return core.normalize_path(tostring(cwd_url))
end

local function basename_of(path)
	if path == "/" then
		return "/"
	end
	return path:match("([^/]+)$") or "/"
end

local function find_record(records, path)
	for _, record in ipairs(records) do
		if record.path == path then
			return record
		end
	end
	return nil
end

-- Общий хвост мутации: персистентность → канонический reload (кандидат не
-- применяется) → отдельная DDS-публикация со сбоями без отката.
local function commit_and_sync(updated)
	local ok, persist_err = persist(updated)
	if not ok then
		notify(persist_err)
		return false
	end
	reload_canonical()
	local pub_ok, pub_err = publish_dds()
	if not pub_ok then
		notify(L.notify_failed:format(tostring(pub_err)))
	end
	return true
end

-- ── действия entry ─────────────────────────────────────────────────────────

-- §9 шаг 9: presentation-текст записи — база (rel-путь или абсолютный) с
-- дописанным label'ом; пустой label опускается.
local function describe(base, record)
	if record.label ~= "" then
		return base .. "  ·  " .. record.label
	end
	return base
end

-- §9 шаги 10–11 (легаси-путь menu.style="which", byte-совместимое поведение):
-- видимый ya.which с клавишами KEY_POOL по порядку и cd по 1-based результату.
local function menu_which(cwd_url, in_scope, global_records, records)
	local cands, targets, overflow = {}, {}, false
	local function add_cand(record, desc)
		local index = #cands + 1
		local key = KEY_POOL:sub(index, index)
		if key == "" then
			overflow = true
			return false
		end
		cands[index] = { on = key, desc = ui.printable(describe(desc, record)) }
		targets[index] = record.path
		return true
	end

	for _, record in ipairs(in_scope) do
		local rel = tostring(Url(record.path):strip_prefix(cwd_url))
		if rel == "" then
			rel = "."
		end
		if not add_cand(record, rel) then
			break
		end
	end
	-- add_cand ставит overflow при исчерпании пула клавиш (уведомление — ниже,
	-- после обоих циклов): глобальные записи отбрасываются с notify даже если
	-- scoped-записи заполнили пул ровно (спец §16).
	for _, record in ipairs(global_records) do
		if not add_cand(record, record.path) then
			break
		end
	end
	if overflow then
		notify(L.overflow:format(#records, #cands))
	end
	if #cands == 0 then
		return
	end

	local choice = ya.which({ cands = cands })
	if not choice then
		return -- Esc / отмена
	end
	local target = targets[choice]
	if target and target ~= "" then
		ya.emit("cd", { Url(target) })
	end
end

-- §9a: pick-оверлей (menu.style="pick", default). Строки строятся ОДИН раз на
-- момент открытия (снапшот: DDS-reload открытого меню их не пересобирает),
-- дальше цикл silent ya.which: каждая активация клавиши даёт render-проход,
-- redraw рисует оверлей по st.menu. Курсор — 1-based по селектируемым
-- строкам (разделитель пропускается); enter/quick-jump → close + cd;
-- esc/q/nil → close. Цикл переспрашивает открытость каждую итерацию.
local function menu_pick(cwd_url, in_scope, records, quick, pool, threshold, empty_scope)
	pool = pool or KEY_POOL
	local rows, overflow = {}, false
	local ordinal = 0
	local function add_row(line, kind, path, group)
		ordinal = ordinal + 1
		if ordinal > #KEY_POOL then
			overflow = true
			return false
		end
		-- Quick-клавиша в префиксе строки (пул конфига или KEY_POOL, без
		-- j/k/q/g — см. menu.lua); без клавиши — отступ той же ширины.
		local key = quick and menu_mod.quick_key(ordinal, pool) or nil
		local prefix = key ~= nil and (key .. "  ") or "   "
		rows[#rows + 1] = {
			kind = kind,
			path = path,
			line = prefix .. line,
			jump = ordinal,
			group = group,
		}
		return true
	end

	-- Текст листа: имя узла + label (§9 шаг 9), base_text — для плоских
	-- корневых строк (rel-путь или полный, как до деревьев).
	local function leaf_line(node, base_text)
		local text = base_text or node.name
		if node.record.label ~= "" then
			return text .. "  ·  " .. node.record.label
		end
		return text
	end

	local function add_nodes(nodes)
		for _, node in ipairs(nodes) do
			if node.kind == "group" then
				if not add_row(("▸ %s  (%d)"):format(node.name, node.count), "group", nil, node) then
					return false
				end
			elseif not add_row(leaf_line(node), "leaf", node.record.path) then
				return false
			end
		end
		return true
	end

	-- Блок записей: > порога — узлы дерева, иначе плоские строки как раньше.
	local function add_block(record_list, flat_base)
		if threshold > 0 and #record_list > threshold then
			return add_nodes(menu_mod.nodes_for(record_list, "", threshold))
		end
		for _, record in ipairs(record_list) do
			local base = record.path
			if flat_base == "rel" then
				base = tostring(Url(record.path):strip_prefix(cwd_url))
				if base == "" then
					base = "."
				end
			end
			if not add_row(leaf_line({ record = record }, base), "leaf", record.path) then
				return false
			end
		end
		return true
	end

	-- Подуровень группы: рекурсивная группировка от базы группы; внутри
	-- ≤ порога — короткие имена листьев, > — снова группы.
	local function group_frame(node)
		return {
			title = node.name,
			render = function()
				return add_nodes(menu_mod.nodes_for(node.records, node.base, threshold))
			end,
		}
	end

	-- Два корневых вида (§9b): scoped (по умолчанию, с разделителем) и
	-- all (g: все закладки одним списком/деревом).
	-- §9c: обычный вид — ТОЛЬКО scoped-блок (дерево cwd), без разделителя
	-- и глобальных строк; все закладки — в g-режиме. scoped пуст →
	-- empty_scope: "all" — сразу все, "message" — пункт-сообщение.
	local root = {
		scoped = {
			title = L.title,
			render = function()
				if #in_scope == 0 then
					rows[#rows + 1] = { kind = "message", line = L.no_scoped_row }
					return
				end
				add_block(in_scope, "rel")
			end,
		},
		all = {
			title = L.title_all:format(#records),
			render = function()
				add_block(records, "abs")
			end,
		},
	}

	local mode = (#in_scope == 0 and empty_scope == "all") and "all" or "scoped"
	local stack = { root[mode] }
	local cursor, nav = 1, nil
	local function open_frame(frame)
		rows, ordinal, overflow = {}, 0, false
		frame.render()
		if overflow then
			notify(L.overflow:format(#records, #KEY_POOL))
		end
		menu_open(rows, frame.title)
		nav = menu_mod.nav_cands(menu_mod.selectable_count(rows), quick, pool)
		cursor = 1
	end
	open_frame(stack[#stack])

	local function descend(node)
		stack[#stack + 1] = group_frame(node)
		open_frame(stack[#stack])
	end

	local function jump_row(row)
		-- сначала закрыть, затем cd по нетронутому абсолютному пути (§9 шаг 11)
		menu_close()
		if row ~= nil and row.path ~= nil then
			ya.emit("cd", { Url(row.path) })
		end
	end

	while menu_is_open() do
		local index = ya.which({ cands = nav.cands, silent = true })
		local action = nav.resolve(index)
		if action == "up" or action == "down" then
			cursor = menu_mod.move_cursor(rows, cursor, action == "up" and -1 or 1)
			menu_move(cursor)
		elseif action == "home" then
			cursor = 1
			menu_move(cursor)
		elseif action == "end" then
			cursor = menu_mod.selectable_count(rows)
			menu_move(cursor)
		elseif action == "enter" or action == "back" or action == "toggle_all" then
			local row = menu_mod.row_by_jump(rows, cursor)
			if action == "back" then
				-- ← на корне ничего (меню живёт); q/Esc закрывают всё
				if #stack > 1 then
					stack[#stack] = nil
					open_frame(stack[#stack])
				end
			elseif action == "toggle_all" then
				mode = mode == "scoped" and "all" or "scoped"
				stack = { root[mode] }
				open_frame(stack[#stack])
			elseif row ~= nil and row.group ~= nil then
				descend(row.group)
			else
				jump_row(row) -- → на листе = прыжок
			end
		elseif action == "select" or type(action) == "table" then
			-- enter/quick: группа → вход, лист → прыжок
			local row = menu_mod.row_by_jump(rows, action == "select" and cursor or action.jump)
			if row ~= nil and row.group ~= nil then
				descend(row.group)
			else
				jump_row(row)
			end
		else -- "close": esc / q / nil (неизвестная клавиша)
			menu_close()
		end
	end
end

-- Меню "'" (§9 шаги 1–8 + §9a): канонический reload → пустой notify →
-- cwd-снапшот → стабильное разбиение → presentation; дальше стиль:
-- "which" — легаси-селектор, "pick" — плавающий оверлей.
local function action_menu()
	reload_canonical()
	local records = get_bookmarks() or {}
	if #records == 0 then
		notify(L.no_bookmarks)
		return
	end

	local cwd_url = get_cwd()
	local scoped_ok = cwd_url ~= nil and cwd_url.is_regular and cwd_url.is_absolute

	-- В обычной локальной панели: равные/потомки cwd — первыми, затем глобальные.
	-- В VFS/поиске starts_with/strip_prefix не вызываются: всё — глобальное.
	local in_scope, global_records
	if scoped_ok then
		in_scope, global_records = core.partition(records, function(record)
			return Url(record.path):starts_with(cwd_url)
		end)
	else
		in_scope, global_records = {}, records
	end

	local config = get_config()
	if config == nil then
		-- entry до setup (через init.lua недостижимо): опции меню — из дефолтов
		-- core (style "pick", quick_jump true), а не quick=false; fresh-таблица,
		-- общие таблицы core.DEFAULTS не мутируются.
		config = {
			menu = {
				style = core.DEFAULTS.menu.style,
				quick_jump = core.DEFAULTS.menu.quick_jump,
				group_threshold = core.DEFAULTS.menu.group_threshold,
			},
		}
	end
	if config.menu ~= nil and config.menu.style == "which" then
		menu_which(cwd_url, in_scope, global_records, records)
		return
	end
	local menu_opts = config.menu or {}
	menu_pick(
		cwd_url,
		in_scope,
		records,
		menu_opts.quick_jump == true,
		menu_opts.quick_pool,
		menu_opts.group_threshold or 0,
		menu_opts.empty_scope or "all"
	)
end

-- Общий prologue действий: VFS-cwd reject → state_paths resolve/notify →
-- read_canonical/notify. Возвращает (path, target, latest) либо nil
-- (уведомление уже отправлено).
local function action_context()
	local path = current_cwd_path()
	if not path then
		notify(L.vfs_reject)
		return nil
	end
	local dir, target = state_paths()
	if not dir then
		notify(target)
		return nil
	end
	local latest, err = read_canonical(target)
	if latest == nil then
		notify(err)
		return nil
	end
	return path, target, latest
end

-- B a: добавить/обновить закладку текущей папки с нативным вводом label.
local function action_add()
	local path, target, latest = action_context()
	if not path then
		return
	end
	-- Последний валидный диск — для префилла текущего label.
	local existing = find_record(latest, path)
	local label, event = ya.input({
		pos = { "center", w = 50 },
		title = "Bookmark label:",
		value = existing and existing.label or basename_of(path),
		obscure = false,
		realtime = false,
	})
	if event ~= 1 then
		return -- cancel: никакого изменения
	end
	if label == nil or label == "" then
		label = basename_of(path)
	end
	-- Свежий reread непосредственно перед мутацией (LWW).
	local fresh, fresh_err = read_canonical(target)
	if fresh == nil then
		notify(fresh_err)
		return
	end
	local updated = core.upsert(fresh, path, label)
	commit_and_sync(updated)
end

-- B d: удалить закладку текущей папки с нативным подтверждением.
local function action_delete()
	local path, target, latest = action_context()
	if not path then
		return
	end
	local current = find_record(latest, path)
	if not current then
		notify(L.no_mark_here)
		return
	end
	local yes = ya.confirm({
		pos = { "center", w = 60, h = 10 },
		title = L.confirm_delete,
		body = ui.Text(current.label .. "\n" .. current.path),
	})
	if not yes then
		return -- cancel/Esc: ничего не делаем
	end
	-- Reread после подтверждения + повторная проверка присутствия.
	local fresh, fresh_err = read_canonical(target)
	if fresh == nil then
		notify(fresh_err)
		return
	end
	local updated, found = core.remove(fresh, path)
	if not found then
		notify(L.deleted_elsewhere)
		return
	end
	commit_and_sync(updated)
end

-- ── маркер строк ───────────────────────────────────────────────────────────

-- Чистый O(1) callback для Entity/Linemode child: два lookup по текущим
-- st.exact/st.below, без I/O, уведомлений, команд, итерации закладок и render.
local function make_marker_callback(st)
	return function(self)
		local file = self._file
		if not file.in_current or not file.cha or not file.cha.is_dir then
			return ""
		end
		local url = file.url
		if not url.is_regular or not url.is_absolute then
			return ""
		end
		local path = core.normalize_path(tostring(url))
		if not path then
			return ""
		end
		local is_exact = st.exact[path] == true
		local count = st.below[path]
		if not is_exact and (count == nil or count == 0) then
			return ""
		end
		local marker = core.marker_text(st.config.marker, is_exact, count)
		if marker == "" then
			return ""
		end
		local text = ui.printable(st.config.marker.separator .. marker)
		-- Для name-слота hovered-строка возвращает plain string, чтобы маркер
		-- наследовал внешний hover-style Entity-строки (как git.yazi).
		if st.config.marker.slot == "name" and file.is_hovered then
			return text
		end
		return ui.Span(text):style(st.marker_style)
	end
end

-- ── pick-оверлей меню ─────────────────────────────────────────────────────

-- Компонент для Modal:children_add (PR #2205, Yazi 26.5.6): Регистрируется
-- один раз в setup при style == "pick" и живёт весь процесс. Modal даёт
-- ПОЛНЫЙ Rect терминала (root.rs → Modal:new(self._area)); reflow без мыши.
-- redraw: закрыто → {} за константное время; открыто → якорь hover-строки
-- по read-only cx + ui.area("current") — ТОЧНЫЙ pane-Rect (26.5.6
-- elements.rs: area() возвращает Rect(LAYOUT.current); ui.redraw(Current)
-- записывает его _area в LAYOUT ДО вызова redraw, а рендер идёт Root →
-- Preview → Modal (root.rs), поэтому на redraw этого компонента
-- LAYOUT.current свежий для кадра), cursor-offset — индекс hover в окне,
-- area.x — колонка панели (сдвиг parent-pane включён); фоллбек — оценка
-- дефолтного Root-лейаута. Чистая геометрия/элементы — menu.lua. Никакого
-- I/O, notify, emit и мутаций состояния.

-- Безопасное чтение координат Rect (реальный Rect — userdata, фейк —
-- таблица): (y, x) числами либо (nil, nil), если r — не Rect.
local function rect_xy(r)
	local ok, y, x = pcall(function()
		return r.y, r.x
	end)
	if ok and type(y) == "number" and type(x) == "number" then
		return y, x
	end
	return nil, nil
end

local function make_menu_component(st)
	return {
		_id = "scoped-marks-menu",
		new = function(self, area)
			self._area = area
			return self
		end,
		reflow = function()
			return {}
		end,
		redraw = function(self)
			local menu = st.menu
			if menu == nil then
				return {}
			end

			local area = self._area or {}
			local term_w = math.floor(tonumber(area.w) or 80)
			local term_h = math.floor(tonumber(area.h) or 24)
			-- Якорь по умолчанию — центр; pcall страхует от нестандартного cx.
			-- Точная модель: ui.area("current") + (cursor − offset); если ui.area
			-- недоступна/вернула не-Rect — оценка дефолтного Root-лейаута
			-- (окно прижато снизу: header 1 / tabs / status 1).
			local anchor_row, anchor_col = term_h // 2, 0
			pcall(function()
				local folder = cx.active.current
				local cursor, offset = folder.cursor, folder.offset
				local ok_area, r = pcall(ui.area, "current")
				local y, x
				if ok_area then
					y, x = rect_xy(r)
				end
				if y ~= nil then
					anchor_row = y + (cursor - offset)
					anchor_col = x
				else
					local visible = #folder.window
					anchor_row = (term_h - 2) - visible + 1 + (cursor - offset)
					anchor_col = 0
				end
			end)
			local geo = menu_mod.geometry(anchor_row, anchor_col, menu.rows, term_w, term_h, menu.title)
			-- th.pick в реальном Yazi — Composer-USERDATA (theme/theme.rs:
			-- Composer::new(get,set) c __index), а НЕ table: type()==="table"
			-- всегда ложно — был live-баг «невидимого курсора». pcall покрывает и
			-- userdata, и table (harness-фейк), и отсутствие/ошибку темы: поля,
			-- которые не удалось прочитать, остаются nil → без стиля, но не падаем.
			local theme = { border = nil, active = nil, inactive = nil }
			pcall(function()
				theme.border = th.pick.border
				theme.active = th.pick.active
				theme.inactive = th.pick.inactive
			end)
			-- Явный бек курсорной строки (menu.cursor_bg) сильнее темы.
			if st.menu_cursor_style ~= nil then
				theme.active = st.menu_cursor_style
			end
			return menu_mod.elements(menu.rows, menu.cursor, geo, theme, menu.title)
		end,
	}
end

-- ── публичный интерфейс ────────────────────────────────────────────────────

local M = {}

function M.setup(st, opts)
	local fg_check = function(value)
		return pcall(function()
			return ui.Style():fg(value)
		end)
	end
	local config, warnings = core.validate_config(opts, fg_check)
	-- Локаль строк — из валидированного конфига (§9c); все дальнейшие
	-- notify/confirm/меню — на выбранном языке.
	L = lang_mod.get(config.menu.lang)
	if #warnings > 0 then
		ya.notify({
			title = "scoped-marks",
			content = "scoped-marks.lua: " .. table.concat(warnings, "; ") .. " — применены значения по умолчанию",
			timeout = 5,
		})
	end
	st.config = config

	st.bookmarks = st.bookmarks or {}
	st.exact = st.exact or {}
	st.below = st.below or {}
	st.latest_epoch = st.latest_epoch or 0
	st.temp_seq = st.temp_seq or 0

	-- Стиль строится и валидируется один раз в setup.
	local style = ui.Style()
	if config.marker.fg ~= nil then
		style = style:fg(config.marker.fg)
	end
	if config.marker.bold then
		style = style:bold()
	end
	st.marker_style = style

	-- Один render-child; повторный setup не дублирует callback.
	if config.marker.enabled and st.marker_child == nil then
		local callback = make_marker_callback(st)
		if config.marker.slot == "linemode" then
			st.marker_child = Linemode:children_add(callback, config.marker.order)
		else
			st.marker_child = Entity:children_add(callback, config.marker.order)
		end
	end

	-- Pick-оверлей: один Modal-компонент с guard'ом (зеркалит маркер);
	-- style == "which" не регистрирует ничего. Настройки рендера меню
	-- применяются со следующего запуска Yazi (§5).
	if config.menu.style == "pick" and st.menu_child == nil then
		st.menu_child = Modal:children_add(make_menu_component(st), 900)
	end

	-- Курсорная строка меню: явный бек из menu.cursor_bg строится ЗДЕСЬ
	-- один раз (валидация цвета уже прошла через bg_check); nil → бек не
	-- задаётся, redraw возьмёт th.pick.active из темы.
	st.menu_cursor_style = nil
	if config.menu.cursor_bg ~= nil then
		local ok_style, built = pcall(function()
			-- Бек + контрастный текст (cursor_fg, по умолчанию чёрный — светлый
			-- на ярком беке читается плохо).
			return ui.Style():bg(config.menu.cursor_bg):fg(config.menu.cursor_fg or "black")
		end)
		st.menu_cursor_style = ok_style and built or nil
	end

	-- Удалённая подписка объявляется ДО первого reload.
	if st.remote_subscription == nil then
		st.remote_subscription = true
		ps.sub_remote(EVENT, function(body)
			if type(body) == "table" and body.origin == APP_ID then
				return -- собственная доставка: guard
			end
			ya.async(function()
				reload_canonical()
			end)
		end)
	end

	-- Локальная cd-подписка: тот же непубликующий упорядоченный reload
	-- для подхвата внешних правок JSON.
	if config.reload_on_cd and st.cd_subscription == nil then
		st.cd_subscription = true
		ps.sub("cd", function()
			ya.async(function()
				reload_canonical()
			end)
		end)
	end

	if st.initial_reload_queued == nil then
		st.initial_reload_queued = true
		ya.async(function()
			reload_canonical()
		end)
	end
end

function M.entry(st, job)
	local action = job.args[1] or "menu"
	if action == "add" then
		action_add()
	elseif action == "delete" then
		action_delete()
	else
		action_menu()
	end
end

return M
