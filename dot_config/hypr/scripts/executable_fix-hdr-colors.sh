#!/bin/bash
# Save as fix-hdr-colors.sh

MONITOR="HDMI-A-2"

echo "Resetting HDR color management for $MONITOR..."

# Just toggle the color management property
ln -sf /home/andrei/.config/hypr/monitor-sdr.conf /home/andrei/.config/hypr/monitor.conf
hyprctl reload
sleep 0.5
ln -sf /home/andrei/.config/hypr/monitor-hdr.conf /home/andrei/.config/hypr/monitor.conf
hyprctl reload
echo "Done!"
