---
name: dotfiles
description: Chezmoi dotfiles management - initialize, sync, add/remove configs, troubleshoot. Use when user mentions dotfiles, chezmoi, config sync, or setup on new machine.
version: 1.0.0
---

# Dotfiles Management with Chezmoi

Управление dotfiles через chezmoi. Инициализация на новых машинах, синхронизация, добавление/удаление конфигов.

## Справочники

- **Troubleshooting**: См. [references/troubleshooting.md](references/troubleshooting.md)
- **Прометеус раскладка**: См. [references/prometheus-layout.md](references/prometheus-layout.md)
- **Установка**: См. [references/workflows.md](references/workflows.md)

## Возможности

- 🚀 **Инициализация** — настройка на новой машине
- 📦 **Добавление** — отслеживание новых конфигов
- 🔄 **Синхронизация** — push/pull между машинами
- 🗑️ **Удаление** — исключение из отслеживания

## Ключевые концепты

```
Source: ~/.local/share/chezmoi/dot_config/  ← твои конфиги
Target: ~/.config/*, ~/*                  ← реальные файлы
```

## Команды chezmoi

| Команда | Описание |
|---------|----------|
| `chezmoi add <path>` | Добавить файл в отслеживание |
| `chezmoi diff` | Показать различия |
| `chezmoi apply` | Применить изменения |
| `chezmoi forget <path>` | Убрать из отслеживания |
| `chezmoi managed` | Список отслеживаемых файлов |

## Пользовательские команды (Nushell)

```nu
dots          # git pull + chezmoi apply
dotsp [msg]   # chezmoi add + git commit + git push
```

## Быстрый старт

### Добавить конфиг

```bash
nvim ~/.config/app/config.conf
chezmoi add ~/.config/app
dotsp "add app config"
```

### Обновиться

```bash
dots
```

### Новая машина

```bash
paru -S chezmoi
chezmoi init git@github.com:Rival/dotfiles.git
chezmoi apply
exec nu
```

## Условные конфиги

Используй проверки для опциональных конфигов:

```nu
if (which zoxide | is-not-empty) {
    zoxide init --cmd cd nushell | save -f ~/.config/zoxide.nu
    if ("~/.config/zoxide.nu" | path expand | path exists) {
        source ~/.config/zoxide.nu
    }
}
```

## XDG стандарты

Конфиги в `~/.config/`, не в `~`:
- ✅ `~/.config/zoxide.nu`
- ❌ `~/.zoxide.nu`

## Исключения (.chezmoignore)

```
# Snapshots
**/.snapshots

# Кеши
**/__pycache__/
**/node_modules/

# История
**/*.bak

# Git репо
**/.git/

# IDE
**/.idea/
**/.vscode/
```

## Интеграция с другими скиллами

- Сохранение project-specific настроек
- Синхронизация конфигов между машинами

## Конфигурация пользователя

- **GitHub**: `git@github.com:Rival/dotfiles.git`
- **Дистрибутив**: CachyOS/Arch Linux
- **Shell**: Nushell
- **Пакеты**: chezmoi, oh-my-posh, nushell, yazi, fzf, neovim, kitty

## Примеры запросов

- "Добавь конфиг wezterm в dotfiles"
- "Запуши изменения"
- "Обнови dotfiles"
- "Удали waybar"
- "Проверь статус"

## Установленные приложения

```
Обязательные:
├── chezmoi       # dotfiles management
├── oh-my-posh    # prompt
├── nushell       # shell
├── yazi          # file manager
├── fzf           # fuzzy search
├── fastfetch     # system info
├── neovim        # editor
├── kitty         # terminal
└── wlogout       # logout menu

Опциональные:
├── hyprland      # WM
└── zoxide        # smart navigation
```
