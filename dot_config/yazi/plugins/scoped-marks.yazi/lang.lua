-- Локализация плагина (§9c). Все пользовательские строки — здесь; код
-- обращается по ключам через M.get(locale). Форматные строки совместимы
-- со string.format (%s/%d). en надстраивается над ru: отсутствующий ключ
-- в en честно отдаёт ru (нет частичных переводов-обрывов).
--
-- Ключи и их использование:
--   title / title_all        — заголовки рамки меню (обычный / g-режим)
--   no_bookmarks             — ' при пустом общем списке
--   no_scoped_row            — пункт-сообщение, когда scoped пуст и
--                              menu.empty_scope == "message"
--   overflow                 — строк больше, чем quick-клавиш
--   vfs_reject               — add/delete в VFS/поиске
--   notify_failed            — persist прошёл, pub-уведомление — нет
--   no_mark_here             — delete без закладки
--   deleted_elsewhere        — закладку удалили в другом процессе
--   confirm_delete           — ya.confirm title
--   xdg_missing / read_*     — диагностика state-файла
--   w_*                      — предупреждения validate_config (core.lua)

local M = {}

M.ru = {
	title = "Закладки",
	title_all = "Все закладки (%d)",
	no_bookmarks = "Нет закладок — B a добавит текущую папку",
	no_scoped_row = "В этом дереве закладок нет — g покажет все",
	overflow = "закладок больше, чем клавиш (%d): показываю первые %d",
	vfs_reject = "VFS/поиск-панель: закладка возможна только в обычной локальной папке",
	notify_failed = "Записано, но уведомить другие процессы не удалось: %s",
	no_mark_here = "Здесь нет закладки",
	deleted_elsewhere = "Закладку уже удалили в другом процессе",
	confirm_delete = "Удалить закладку?",
	xdg_missing = "XDG_STATE_HOME/HOME не заданы: путь состояния не разрешается",
	read_err = "чтение %s: %s",
	read_stream = "чтение %s: ошибка потока",
	read_empty = "чтение %s: файл пуст",
	read_json = "JSON %s: %s",
	read_schema = "схема %s: %s",
	w_config = "конфиг должен быть таблицей",
	w_menu_table = "menu должен быть таблицей",
	w_menu_style = 'menu.style должен быть "pick" или "which"',
	w_menu_quick_jump = "menu.quick_jump должен быть boolean",
	w_menu_cursor_bg = "menu.cursor_bg должен быть цветом, принимаемым ui.Style():bg",
	w_menu_cursor_fg = "menu.cursor_fg должен быть цветом, принимаемым ui.Style():fg",
	w_menu_quick_pool = "menu.quick_pool должен быть непустой строкой символов",
	w_menu_group_threshold = "menu.group_threshold должен быть целым числом ≥ 0",
	w_menu_empty_scope = 'menu.empty_scope должен быть "all" или "message"',
	w_menu_lang = 'menu.lang должен быть "ru" или "en"',
	w_marker_table = "marker должен быть таблицей",
	w_marker_enabled = "marker.enabled должен быть boolean",
	w_marker_slot = 'marker.slot должен быть "name" или "linemode"',
	w_marker_order = "marker.order должен быть конечным числом",
	w_marker_field = "marker.%s должен быть строкой",
	w_marker_fg = "marker.fg не принят стилем — сброшен к default",
	w_marker_bold = "marker.bold должен быть boolean",
	w_reload_on_cd = "reload_on_cd должен быть boolean",
}

M.en = {
	title = "Bookmarks",
	title_all = "All bookmarks (%d)",
	no_bookmarks = "No bookmarks — B a adds the current folder",
	no_scoped_row = "No bookmarks under this tree — g shows all",
	overflow = "more bookmarks than keys (%d): showing first %d",
	vfs_reject = "VFS/search pane: bookmarks work in regular local folders only",
	notify_failed = "Saved, but failed to notify other processes: %s",
	no_mark_here = "No bookmark here",
	deleted_elsewhere = "The bookmark was already deleted by another process",
	confirm_delete = "Delete bookmark?",
	xdg_missing = "XDG_STATE_HOME/HOME unset: state path is unresolvable",
	read_err = "reading %s: %s",
	read_stream = "reading %s: stream error",
	read_empty = "reading %s: file is empty",
	read_json = "JSON %s: %s",
	read_schema = "schema %s: %s",
	w_config = "config must be a table",
	w_menu_table = "menu must be a table",
	w_menu_style = 'menu.style must be "pick" or "which"',
	w_menu_quick_jump = "menu.quick_jump must be boolean",
	w_menu_cursor_bg = "menu.cursor_bg must be a color accepted by ui.Style():bg",
	w_menu_cursor_fg = "menu.cursor_fg must be a color accepted by ui.Style():fg",
	w_menu_quick_pool = "menu.quick_pool must be a non-empty string of characters",
	w_menu_group_threshold = "menu.group_threshold must be an integer ≥ 0",
	w_menu_empty_scope = 'menu.empty_scope must be "all" or "message"',
	w_menu_lang = 'menu.lang must be "ru" or "en"',
	w_marker_table = "marker must be a table",
	w_marker_enabled = "marker.enabled must be boolean",
	w_marker_slot = 'marker.slot must be "name" or "linemode"',
	w_marker_order = "marker.order must be a finite number",
	w_marker_field = "marker.%s must be a string",
	w_marker_fg = "marker.fg rejected by style — reset to default",
	w_marker_bold = "marker.bold must be boolean",
	w_reload_on_cd = "reload_on_cd must be boolean",
}

-- Доступные локали (для валидации menu.lang).
M.locales = { ru = true, en = true }

-- Разрешённая таблица строк: en поверх ru (фолбэк ключей), иначе ru.
function M.get(locale)
	if locale ~= "en" then
		return M.ru
	end
	local merged = {}
	for key, value in pairs(M.ru) do
		merged[key] = value
	end
	for key, value in pairs(M.en) do
		merged[key] = value
	end
	return merged
end

return M
