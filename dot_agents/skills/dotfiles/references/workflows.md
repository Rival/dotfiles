# Dotfiles — Workflows

Практические workflows для типовых сценариев.

## Добавить новый конфиг

### Полный процесс

```bash
# 1. Редактируешь конфиг
nvim ~/.config/some-app/config.conf

# 2. Добавляешь в chezmoi
chezmoi add ~/.config/some-app

# 3. Коммитишь и пушишь (одной командой)
dotsp "add some-app config"
```

### Развернуто

```bash
# Редактирование
nvim ~/.config/wezterm/wezterm.lua

# Добавление в chezmoi
chezmoi add ~/.config/wezterm

# Проверь что добавилось
chezmoi managed | grep wezterm

# Коммит и push
cd ~/.local/share/chezmoi
git status
git diff dot_config/wezterm/wezterm.lua
git add -A
git commit -m "Add wezterm config"
git push
```

---

## Обновиться с GitHub

### Настроенной машине

```bash
# Одна команда
dots
```

**Что происходит:**
1. `cd ~/.local/share/chezmoi`
2. `git pull` — подтянет изменения
3. `chezmoi apply` — применит к целевым файлам

### Развернуто

```bash
cd ~/.local/share/chezmoi

# Потянуть изменения
git pull

# Применить к системе
chezmoi apply

# Если были конфликты
# vim dot_config/nvim/init.lua  # разрешить
# git add -A
# git commit -m "Resolve merge"
# git push

# Перезапустить shell чтобы применить
exec nu
```

---

## Инициализация на новой машине

### Через install скрипт (рекомендуется)

```bash
curl -sSL https://raw.githubusercontent.com/Rival/dotfiles/main/install.sh | bash
```

**Скрипт:**
1. Установит обязательные пакеты
2. Спросит про опциональные (hyprland, zoxide)
3. Клонирует dotfiles repo
4. Применит конфиги

### Вручную

```bash
# 1. Установить chezmoi
paru -S chezmoi

# 2. Клонировать dotfiles
chezmoi init git@github.com:Rival/dotfiles.git

# 3. Применить конфиги
chezmoi apply

# 4. Перезапустить shell
exec nu
```

---

## Удалить конфиг из отслеживания

```bash
# Убрать из отслеживания
chezmoi forget ~/.config/app

# Удалить файл
rm ~/.config/app

# Применить изменения
chezmoi apply

# Запушить
cd ~/.local/share/chezmoi
git add -A
git commit -m "Remove app config"
git push
```

---

## Перенести конфиг в другое место

### Из ~/.config в ~/dot_config

```bash
# 1. Создать новое место
mkdir -p ~/dot_config/app

# 2. Переместить
mv ~/.config/app ~/dot_config/

# 3. Убрать старый
chezmoi forget ~/.config/app

# 4. Добавить новый
chezmoi add ~/dot_config/app

# 5. Обновить симлинк если есть
ln -sf ~/dot_config/app ~/.config/app
```

---

## Создать новый конфиг с нуля

### Пример: новый app

```bash
# 1. Создать директорию
mkdir -p ~/.config/myapp

# 2. Создать конфиг
nvim ~/.config/myapp/config.conf
# ... редактирование ...

# 3. Добавить в chezmoi
chezmoi add ~/.config/myapp

# 4. Запушить
dotsp "add myapp config"
```

---

## Восстановить конфиг из истории

```bash
cd ~/.local/share/chezmoi

# Посмотреть историю
git log --oneline dot_config/myapp/config.conf

# Восстановить определённую версию
git checkout abc1234 -- dot_config/myapp/config.conf

# Применить
chezmoi apply

# Если нужно оставить эту версию
git add -A
git commit -m "Restore config to version abc1234"
git push
```

---

## Проверить статус

### Что отслеживается

```bash
chezmoi managed
```

### Что изменилось

```bash
# Различия source vs target
chezmoi diff

# Различия в конкретном файле
chezmoi diff ~/.config/nvim/init.lua
```

### Статус git

```bash
cd ~/.local/share/chezmoi
git status
```

---

## Синхронизация между машинами

### С машины A на машину B

**Машина A:**
```bash
# Работа с конфигами
nvim ~/.config/nvim/init.lua

# Запушить
dotsp "update nvim config"
```

**Машина B:**
```bash
# Подтянуть изменения
dots
```

---

## Backup и restore

### Backup перед экспериментами

```bash
# Создать tag
cd ~/.local/share/chezmoi
git tag backup-before-experiment

# Или branch
git checkout -b backup
```

### Restore если что-то сломалось

```bash
# Откатиться к tag
git checkout backup-before-experiment

# Или к branch
git checkout main
git branch -D backup
```

---

## Оптимизация репозитория

### Очистить от больших бинарников

```bash
cd ~/.local/share/chezmoi

# Проверить размер
du -sh dot_config/

# Если есть большие файлы, добавить в .gitignore
echo "**/large-file.bin" >> .gitignore
git add -A
git commit -m "Add large files to ignore"
```

### Сжатие истории (если нужно)

```bash
# Осторожно! Переписывает историю
git gc --aggressive --prune=now
```
