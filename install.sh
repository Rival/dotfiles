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
    wlogout

# Optional: hyprland
echo ""
read -p "Install Hyprland WM? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📦 Installing hyprland..."
    paru -S --noconfirm --needed hyprland
    HYPRLAND_INSTALLED=true
else
    echo "⏭️  Skipping hyprland"
    HYPRLAND_INSTALLED=false
fi

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

# Optional: Prometheus keyboard layout (after chezmoi apply)
echo ""
read -p "Install Prometheus keyboard layout? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "⌨️  Installing Prometheus keyboard layout..."
    sudo cp ~/.local/share/xkeyboard-config/symbols/prometeus /usr/share/X11/xkb/symbols/prometeus
    PROMETHEUS_INSTALLED=true
else
    echo "⏭️  Skipping Prometheus layout"
    PROMETHEUS_INSTALLED=false
fi

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
if [ "$PROMETHEUS_INSTALLED" = true ]; then
    echo "  5. ⌨️  Prometheus layout installed!"
    echo "     🔄 IMPORTANT: Restart your display manager or logout/login to use it"
    echo "     To remove later: prometheus-remove"
fi
echo ""
echo "🎯 Configured apps:"
echo "  • nushell + oh-my-posh"
echo "  • neovim"
echo "  • kitty"
echo "  • yazi"
echo "  • fastfetch"
if [ "$HYPRLAND_INSTALLED" = true ]; then
    echo "  • hyprland"
fi
if [ "$PROMETHEUS_INSTALLED" = true ]; then
    echo "  • prometheus keyboard layout"
fi
