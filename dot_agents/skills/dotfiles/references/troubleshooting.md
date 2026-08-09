# Dotfiles — Troubleshooting

Решение типичных проблем при работе с chezmoi dotfiles.

## sourced_file_not_found

### Проблема

Файл не существует при попытке `source` в конфиге.

**Пример ошибки:**
```
Error: sourced_file_not_found
  --> ~/.config/nushell/config.nu:45:32
```

### Решение

Добавь проверку существования файла:

```nu
# ❌ Плохо - упадёт если файл не существует
source ~/.config/file.nu

# ✅ Хорошо - проверка перед source
if ("~/.config/file.nu" | path expand | path exists) {
    source ~/.config/file.nu
}
```

**Для Python:**
```python
import os
config_path = os.path.expanduser("~/.config/file.conf")
if os.path.exists(config_path):
    # Load config
    pass
```

---

## Permission denied на .snapshots

### Проблема

Btrfs snapshots имеют restricted permissions, chezmoi не может их читать.

**Пример ошибки:**
```
Error: Permission denied: /.snapshots/...
```

### Решение

Добавь в `~/.local/share/chezmoi/.chezmoignore`:

```
# Btrfs/restic snapshots
.snapshots
**/.snapshots
```

---

## Symlinks pointing to old repo

### Проблема

Файлы symlinked на старый репозиторий, chezmoi confuses.

**Пример:**
```
~/.config/file -> /old/repo/file
```

### Решение

Замени symlink на реальный файл:

```bash
# 1. Скопировать содержимое
cp --remove-destination /path/to/target ~/.config/file

# 2. Убрать из отслеживания
chezmoi forget ~/.config/file

# 3. Добавить реальный файл
chezmoi add ~/.config/file
```

---

## git push rejected

### Проблема

Изменения в dotfiles конфликтуют с GitHub.

**Пример ошибки:**
```
! [rejected] main -> main (fetch first)
error: failed to push some refs
```

### Решение

```bash
cd ~/.local/share/chezmoi

# Потянуть изменения сначала
git pull --rebase

# Разрешить конфликты если есть
#vim dot_config/nvim/init.lua

# Запушить снова
git push
```

---

## chezmoi apply не применяется

### Проблема

Изменения в source не применяются к target.

### Причины и решения

1. **Файл не добавлен в source:**
   ```bash
   chezmoi add ~/.config/file.conf
   ```

2. **Изменения не закоммичены:**
   ```bash
   cd ~/.local/share/chezmoi
   git status
   git add -A
   git commit -m "Update file"
   ```

3. **Файл в .chezmoignore:**
   ```bash
   # Проверить
   cat ~/.local/share/chezmoi/.chezmoignore | grep file.conf
   ```

4. **Права доступа:**
   ```bash
   # chezmoi должен иметь права на запись
   ls -la ~/.config/
   ```

---

## Условные конфиги не работают

### Проблема

Конфиг для опционального пакета вызывает ошибку когда пакет не установлен.

### Решение

Всегда оборачивай в условные проверки:

```nu
# ❌ Плохо - упадёт если zoxide не установлен
zoxide init --cmd cd nushell | save -f ~/.config/zoxide.nu
source ~/.config/zoxide.nu

# ✅ Хорошо - безопасная проверка
if (which zoxide | is-not-empty) {
    zoxide init --cmd cd nushell | save -f ~/.config/zoxide.nu
    if ("~/.config/zoxide.nu" | path expand | path exists) {
        source ~/.config/zoxide.nu
    }
}
```

---

## Nushell изменения не применяются

### Проблема

Изменил `config.nu`, но после `exec nu` изменений нет.

### Решение

1. **Проверь что файл в source:**
   ```bash
   chezmoi managed | grep config.nu
   ```

2. **Примени изменения:**
   ```bash
   chezmoi apply
   ```

3. **Перезапусти shell:**
   ```bash
   exec nu
   ```

---

## Git статус "dirty"

### Проблема

`chezmoi status` показывает что файлы изменены, хотя ты их не трогал.

### Причины

1. **Целевой файл изменён напрямую:**
   ```bash
   # Ты редактировал ~/.config/file.conf напрямую
   # chezmoi видит разницу с source
   ```

2. **Решение:**
   ```bash
   # Применить изменения source к target
   chezmoi apply

   # ИЛИ добавить изменения в source
   chezmoi add ~/.config/file.conf
   ```

---

## Конфиг не применяется на новой машине

### Проблема

После `chezmoi apply` конфиг не работает.

### Чек-лист

1. **Пакеты установлены?**
   ```bash
   which nvim kitty nushell
   ```

2. **Условные проверки?**
   ```nu
   # Проверь что все опциональные конфиги обёрнуты в if
   if (which app | is-not-empty) { ... }
   ```

3. **Путь правильный?**
   ```bash
   # XDG: ~/.config/ (не ~/.)
   ls -la ~/.config/
   ```

---

## .chezmoignore не работает

### Проблема

Файлы игнорируются, но всё равно отслеживаются.

### Решение

Проверь синтаксис `.chezmoignore`:

```
# ❌ Плохо - wildcard в начале
*.log

# ✅ Хорошо - правильный wildcard
**/*.log
```

**Правила .chezmoignore:**
- `**/` — рекурсивно в любых поддиректориях
- `*.log` — только в текущей директории
- `**/*.log` — все .log файлы рекурсивно

---

## Прометеус раскладка не применяется

### Проблема

После установки прометеус раскладки переключение не работает.

### Решение

См. [prometheus-layout.md](prometheus-layout.md) — раздел "Установка и проверка".

Кратко:
1. Перезапусти дисплей менеджер или перелогинься
2. В KDE: System Settings → Keyboard → Layouts
3. Проверь что `prometeus` есть в списке
