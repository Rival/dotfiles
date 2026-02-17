# pyright: reportMissingImports=false
import sys

from kitty.boss import Boss
from kitty.window import Window
from typing import Any


def set_background_image(boss: Boss, window: Window, msg: str) -> None:
    """Set background image for the window."""
    try:
        boss.call_remote_control(
            window,
            ['set-background-image', '--layout=tiled', '-c=yes', f'/home/andrei/Documents/{msg}']
        )
    except Exception as e:
        print(f"Failed to set background image: {e}", file=sys.stderr)


def on_resize(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    """
    Called when window is resized.
    Also called the first time a window is created.
    """
    _ = data  # Unused but required by watcher API
    set_background_image(boss, window, "dark-denim-tile-6.png")
