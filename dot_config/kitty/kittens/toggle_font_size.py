# pyright: reportMissingImports=false
import os
import subprocess
from kitty.boss import Boss
from kittens.tui.handler import result_handler

STATE_FILE = os.path.expanduser("~/.kitty_font_size_state")

def get_current_size():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            try:
                return int(f.read().strip())
            except ValueError:
                return 13  # Default if file content is invalid
    return 13  # Default starting size

def set_new_size(boss, w, current_size):
    new_size = 8 if current_size == 13 else 13
    # subprocess.run(["kitty", "@", "set-font-size", str(new_size)])
    boss.call_remote_control(w, ('set-font-size',str(new_size)))
    with open(STATE_FILE, "w") as f:
        f.write(str(new_size))

def main(args: list[str]) -> str:
    return ""  # No arguments needed for TUI

@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss: Boss) -> None:
    # get the kitty window to which to send text
    w = boss.window_id_map.get(target_window_id)
    if w is not None:
        # boss.call_remote_control(w, ('send-text', f'--match=id:{w.id}', 'hello world'))
        current_size = get_current_size()
        set_new_size(boss, w, current_size)
