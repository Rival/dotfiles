#!/bin/bash
# Remove Prometheus keyboard layout from system

echo "🗑️  Removing Prometheus keyboard layout..."

if [ ! -f "/usr/share/xkeyboard-config/symbols/prometeus" ]; then
    echo "⚠️  Prometheus layout not found in system"
    echo "   File /usr/share/xkeyboard-config/symbols/prometeus does not exist"
    exit 0
fi

sudo rm /usr/share/xkeyboard-config/symbols/prometeus

if [ $? -eq 0 ]; then
    echo "✅ Prometheus layout removed successfully"
    echo ""
    echo "📝 Note: You may need to:"
    echo "   1. Restart your display manager or logout/login"
    echo "   2. Or run: sudo systemctl restart display-manager"
else
    echo "❌ Failed to remove Prometheus layout"
    exit 1
fi
