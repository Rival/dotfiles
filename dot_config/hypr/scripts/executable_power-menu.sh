#!/bin/bash

chosen=$(printf "⏻ Shutdown\n Reboot\n Logout\n" | wofi --dmenu --prompt "Power Menu")

case "$chosen" in
    "⏻ Shutdown") systemctl poweroff ;;
    " Reboot") systemctl reboot ;;
    " Logout") hyprctl dispatch exit ;; # or `swaymsg exit` or whatever matches your WM
esac
