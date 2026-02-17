# pyright: reportMissingImports=false

import os
import sys
from kitty.boss import Boss
from kittens.tui.handler import result_handler

# Add ~/.config/kitty/ to sys.path
config_dir = os.path.expanduser("~/.config/kitty/")
if config_dir not in sys.path:
    sys.path.insert(0, config_dir)
from utils import log

@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss: Boss) -> None:
    """
    Handle messages sent from Neovim.
    Forces tab bar redraw when Neovim tabs change.
    """
    try:
        log(f"handle_result called: target_window_id={target_window_id}, args={args}")

        # Force a tab bar redraw by calling mark_tab_bar_dirty on the active tab manager
        tab = boss.active_tab
        if tab is not None:
            log(f"called mark dirty {tab.title}")
            tab.mark_tab_bar_dirty()

    except Exception as e:
        print(f"Error processing nvim tab data: {e}")
