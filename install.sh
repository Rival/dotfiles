#!/bin/bash
# Dotfiles installer for CachyOS/Arch
# Run: curl -sSL https://raw.githubusercontent.com/Rival/dotfiles/main/install.sh | bash

set -e

echo "🚀 Installing Rival's dotfiles..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running on Arch/CachyOS
if ! command -v pacman &> /dev/null; then
    echo "❌ This script is designed for Arch/CachyOS (pacman not found)"
    exit 1
fi

# Install paru if not present
if ! command -v paru &> /dev/null; then
    echo "📦 Installing paru..."
    sudo pacman -S --needed base-devel git
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd -
    rm -rf "$tmp_dir"
fi

# Install required packages
echo "📦 Installing required packages..."
paru -S --noconfirm --needed \
    chezmoi \
    oh-my-posh \
    nushell \
    yazi \
    fzf \
    fastfetch \
    neovim \
    kitty \
    hyprland \
    waybar \
    wlogout

# Optional: zoxide
echo ""
read -p "Install zoxide? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📦 Installing zoxide..."
    paru -S --noconfirm --needed zoxide
    ZOXIDE_INSTALLED=true
else
    echo "⏭️  Skipping zoxide"
    ZOXIDE_INSTALLED=false
fi

# Clone and apply dotfiles
echo ""
echo "📥 Cloning dotfiles from GitHub..."
chezmoi init git@github.com:Rival/dotfiles.git

echo "📦 Applying dotfiles..."
chezmoi apply

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "📝 Next steps:"
echo "  1. Restart your shell or run: exec nu"
echo "  2. Run 'dots' to update dotfiles from GitHub"
echo "  3. Run 'dotsp' to push changes to GitHub"
if [ "$ZOXIDE_INSTALLED" = true ]; then
    echo "  4. zoxide is installed - use 'z' command for smart navigation"
fi
echo ""
echo "🎯 Configured apps:"
echo "  • nushell + oh-my-posh"
echo "  • neovim"
echo "  • kitty"
echo "  • yazi"
echo "  • hyprland"
echo "  • fastfetch"
