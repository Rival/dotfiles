# Chezmoi Workflows

## Новая машина

```bash
# 1. Установить chezmoi
paru -S chezmoi

# 2. Клонировать и применить
chezmoi init git@github.com:Rival/dotfiles.git
chezmoi apply

# 3. Установить diff tools для LazyGit
~/.local/bin/install-diff-tools.sh

# 4. Перезапустить shell
exec nu
```

## Обновление

```bash
dots  # git pull + chezmoi apply
```

## Добавить конфиг

```bash
nvim ~/.config/app/config.conf
chezmoi add ~/.config/app
dotsp "add app config"
```
