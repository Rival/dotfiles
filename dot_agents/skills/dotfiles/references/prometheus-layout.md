# Prometheus Keyboard Layout

Кастомная оптимизированная раскладка клавиатуры ("Prometheus").

## Структура

```
~/.local/share/xkeyboard-config/symbols/prometeus  # XKB символы
~/.config/kxkbrc                                   # KDE конфиг
```

## Установка

### Автоматически (через Nushell)

```nu
prometheus-install    # Установить в систему
```

### Вручную

```bash
sudo cp ~/.local/share/xkeyboard-config/symbols/prometeus \
      /usr/share/X11/xkb/symbols/prometeus

# Перезапустить дисплей менеджер или перелогиниться
```

## KDE Plasma конфиг

**Файл:** `~/.config/kxkbrc`

```
DisplayNames=us,ru        # Показывает флаги 🇺🇸/🇷� в трее
LayoutList=prometeus,ru   # Прометеус + русская
```

## После установки

1. Перезапустить дисплей менеджер или logout/login
2. В KDE: System Settings → Keyboard → Layouts
3. В трее: флаги стран вместо текстовых кодов

## Удаление

### Автоматически

```nu
prometheus-remove     # Удалить из системы
```

### Вручную

```bash
sudo rm /usr/share/X11/xkb/symbols/prometeus
# Перезапустить дисплей менеджер
```

## XKB путь

- ✅ Правильно: `/usr/share/X11/xkb/symbols/`
- ❌ Неправильно: `/usr/share/xkeyboard-config/symbols/` (устаревший)

## Nushell команды

Определены в `~/.config/nushell/config.nu`:

```nu
def prometheus-install [] {
    print "Установка Prometheus layout..."

    let source = "~/.local/share/xkeyboard-config/symbols/prometeus"
    let target = "/usr/share/X11/xkb/symbols/prometeus"

    if ($source | path expand | path exists) {
        sudo cp ($source | path expand) $target
        print "✅ Установлено! Перезапустите дисплей менеджер."
    } else {
        print "❌ Файл не найден: ($source)"
    }
}

def prometheus-remove [] {
    let target = "/usr/share/X11/xkb/symbols/prometeus"

    if ($target | path exists) {
        sudo rm $target
        print "✅ Удалено! Перезапустите дисплей менеджер."
    } else {
        print "❌ Файл не найден: ($target)"
    }
}
```

## Особенности

### Оптимизация

- **Программирование**: удобные символы
- **Русский/English**: переключение одним модификатором
- **Альтернативные символы**: оптимизированы для кода

### Совместимость

- Работает с XKB-совместимыми DE
- Тестировано на KDE Plasma
- Поддерживается в Hyprland

## Troubleshooting

### Раскладка не применяется после установки

**Решение:**
1. Перезапусти дисплей менеджер
2. Или перелогинься
3. В KDE: System Settings → Keyboard → Layouts

### Флаги не показываются в трее

**Проверь `~/.config/kxkbrc`:**
```
DisplayNames=us,ru    # Должно быть установлено
```

### Прометеус не появился в списке layouts

**Проверь файл существует:**
```bash
ls -la ~/.local/share/xkeyboard-config/symbols/prometeus
ls -la /usr/share/X11/xkb/symbols/prometeus
```

### В KDE не переключается

**Проверь конфиг:**
```bash
cat ~/.config/kxkbrc
# Должно содержать:
# LayoutList=prometeus,ru
# DisplayNames=us,ru
```
