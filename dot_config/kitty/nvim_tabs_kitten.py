# pyright: reportMissingImports=false

import os
import sys
from kitty.boss import Boss

# Add ~/.config/kitty/ to sys.path
config_dir = os.path.expanduser("~/.config/kitty/")
if config_dir not in sys.path:
    sys.path.insert(0, config_dir)
from utils import log

# _boss_instance = None
# # Global variables for debouncing
# _last_update_time = 0
# def delayed_redraw():
#     """Function called after the timer expires to actually redraw the tab bar."""
#     global _boss_instance, _pending_data, _last_update_time
#     try:
#         if _boss_instance is not None:
#             tm = _boss_instance.active_tab_manager
#             if tm is not None:
#                 log("calling mark dirty")
#                 tm.mark_tab_bar_dirty()
#     except Exception as e:
#         print(f"Error in delayed_redraw: {e}", file=sys.stderr)

def main(args: list[str])-> str:
    pass

from kittens.tui.handler import result_handler
@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss: Boss) -> None:
    """
    Handle messages sent from Neovim.
    The first argument should be a JSON-encoded string with tab information.
    """
    # global _redraw_timer, _boss_instance
    # debug('whatever')
    try:
        # env_var = os.environ['KITTY_MY_VAR'] 
        # w = boss.window_id_map.get(target_window_id)
        log(f"handle_result called: target_window_id={target_window_id}, args={args}")
        # if not args or len(args) < 2:
        #     print("Error: No tab data provided")
        #     return

        # Parse the JSON data from Neovim
        # tab_data = json.loads(args[0])

        # Store the data in a global variable that can be accessed by tab_bar.py
        # We'll use an environment variable since there's no direct API for custom tab bar data
        # os.environ['NVIM_TAB_DATA'] = args[1]
            # get the kitty window to which to send text
        # w = boss.window_id_map.get(target_window_id)
        # if w is not None:
        #     boss.call_remote_control(w, ('set-tab-title', f'--match=id:{w.id}', 'hello world'))

        # Store the boss instance for the delayed callback
        # _boss_instance = boss
        # # Cancel any existing timer
        # if _redraw_timer is not None:
        #     log("cancelling timer")
        #     _redraw_timer.cancel()
        # else:
        #     log("creating timer")
        #
        # # Start a new timer for 500ms
        # _redraw_timer = threading.Timer(2, delayed_redraw)
        # _redraw_timer.start()

        # # Force a tab bar redraw by calling mark_tab_bar_dirty on the active tab manager
        tab = boss.active_tab
        if tab is not None:
            # tab.title = "Hello"
            log(f"called mark dirty {tab.title}")
            tab.mark_tab_bar_dirty()


    except Exception as e:
        print(f"Error processing nvim tab data: {e}")
