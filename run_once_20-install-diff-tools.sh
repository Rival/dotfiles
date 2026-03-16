#!/bin/env bash
# Установка инструментов для красивого diff (delta + bat)

set -e

echo "🔧 Installing delta and bat for LazyGit..."

# Проверка установлен ли paru
if ! command -v paru &> /dev/null; then
    echo "❌ paru not found. Please install paru first."
    exit 1
fi

# Установка delta и bat
paru -S --noconfirm --needed delta bat

echo "✅ Done! delta and bat installed."
