# pyright: reportMissingImports=false
import subprocess
import sys
import psutil
from typing import Any

from kitty.boss import Boss
from kitty.window import Window
EnglishLanguageIndex = 0
LanguageIndexBeforeFocus = -1


def set_background_image(boss: Boss, window: Window, msg:str) -> None:
    # notify_send("background changes")
    try:
        # Use boss.call_remote_control instead of subprocess
        boss.call_remote_control(
            window, 
            ['set-background-image', '--layout=tiled', '-c=yes', f'/home/andrei/Documents/{msg}']
        )
    except Exception as e:
        print(f"Failed to set background image: {e}", file=sys.stderr)
    # try:
    #     subprocess.run([
    #         "kitten", "@", "set-background-image", 
    #         "--layout=tiled", 
    #         "-c=yes", 
    #         f"/home/andrei/Documents/{msg}"
    #     ], check=True)
    # except subprocess.CalledProcessError as e:
    #     print(f"Failed to set background image: {e}", file=sys.stderr)
    # except FileNotFoundError:
    #     print("kitten command not found", file=sys.stderr)

# def on_load(boss: Boss, data: dict[str, Any]) -> None:
#     # This is a special function that is called just once when this watcher
#     # module is first loaded, can be used to perform any initializztion/one
#     # time setup. Any exceptions in this function are printed to kitty's
#     # STDERR but otherwise ignored.

#
def on_resize(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    # Here data will contain old_geometry and new_geometry
    # Note that resize is also called the first time a window is created
    # which can be detected as old_geometry will have all zero values, in
    # particular, old_geometry.xnum and old_geometry.ynum will be zero.
    set_background_image(boss, window, "dark-denim-tile-6.png")

def notify_send(msg:str)-> None:
    subprocess.run([
        "notify-send",
        "--app-name=Kitty",
        "--urgency=normal",
        # summary,
        f"Current:{msg}"
        # body
        # flat_data
    ], check=True)

# def switch_layout(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     global LanguageIndexBeforeFocus  # Declare global inside the function
#     global EnglishLanguageIndex  # Declare global inside the function
#     # Extract the new title from data
#     # Log for debugging (optional)
#     try:
#         focused = data.get("focused", False)
#         result_current_language = subprocess.run(["/home/andrei/.scripts/plasma/layout-current-get.sh"], check=True, capture_output = True, text = True)
#         layout_result = result_current_language.stdout.strip()  # Get the layout, strip extra spaces
#         layout_index = int(layout_result)
#
#         if focused:
#             if layout_index != 0:
#                 LanguageIndexBeforeFocus = layout_index
#                 # subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", f"{EnglishLanguageIndex}"], check=True)
#                 subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", "0"], check=True)
#                 # print(f"Kitty focused. Language was {result_current_language.returncode} switching to English") 
#             else:
#                 LanguageIndexBeforeFocus = 0
#         else:        
#             if LanguageIndexBeforeFocus > 0:
#                 switch_result = subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", f"{LanguageIndexBeforeFocus}"], check=True)
#                 # print(f"Kitty language was {result.returncode} switching to {switch_result.result}") 
#     except subprocess.CalledProcessError as e:
#         print(f"Error running script: {e}")
#     # except FileNotFoundError:

# def on_focus_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     set_background_image(boss, window, "dark-denim-tile-6.png")
    # Join sys.path with newlines
    # path_str = "\n".join(sys.path)
    # notify_send(path_str)
    # if data['focused']:
    #     pid = window.child.pid
    #     try:
    #         # Get the shell process (likely Nushell)
    #         shell_process = psutil.Process(pid)
    #         # Check child processes for the foreground app
    #         for child in shell_process.children(recursive=True):
    #             cmdline = child.cmdline()
    #             if cmdline:  # Ensure cmdline is not empty
    #                 cmd = cmdline[0].split('/')[-1]  # Get the executable name
    #                 NotifySend(cmd)
    #                 if cmd in ['yazi', 'lazygit']:
    #                     # boss.set_colors_for_window(window.id, background='green' if cmd == 'yazi' else 'blue')
    #                     NotifySend(cmd)
    #                     return
    #
    #         # Fallback to shell if no relevant child found
    #         cmdline = shell_process.cmdline()
    #         if cmdline:
    #             cmd = cmdline[0].split('/')[-1]
    #             # boss.set_colors_for_window(window.id, background='default')
    #             NotifySend(cmd)
    #     except (psutil.NoSuchProcess, psutil.AccessDenied):
    #         pass


    # switch_layout(boss, window, data)
    # global LanguageIndexBeforeFocus  # Declare global inside the function
    # global EnglishLanguageIndex  # Declare global inside the function
    # # Extract the new title from data
    # # Log for debugging (optional)
    # try:
    #     focused = data.get("focused", False)
    #     result_current_language = subprocess.run(["/home/andrei/.scripts/plasma/layout-current-get.sh"], check=True, capture_output = True, text = True)
    #     layout_result = result_current_language.stdout.strip()  # Get the layout, strip extra spaces
    #     layout_index = int(layout_result)
    #     subprocess.run([
    #         "notify-send",
    #         "--app-name=Kitty",
    #         "--urgency=normal",
    #         # summary,
    #         f"Current:{layout_index}"
    #         # body
    #         # flat_data
    #     ], check=True)
    #     if focused:
    #         if layout_index != 0:
    #             LanguageIndexBeforeFocus = layout_index
    #             # subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", f"{EnglishLanguageIndex}"], check=True)
    #             subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", "0"], check=True)
    #             # print(f"Kitty focused. Language was {result_current_language.returncode} switching to English") 
    #         else:
    #             LanguageIndexBeforeFocus = 0
    #     else:        
    #         if LanguageIndexBeforeFocus > 0:
    #             switch_result = subprocess.run(["/home/andrei/.scripts/plasma/layout-current-set.sh", f"{LanguageIndexBeforeFocus}"], check=True)
    #             # print(f"Kitty language was {result.returncode} switching to {switch_result.result}") 
    # except subprocess.CalledProcessError as e:
    #     print(f"Error running script: {e}")
    # except FileNotFoundError:
    #     print(f"Script not found: {script_path}")

# def on_close(boss: Boss, window: Window, data: dict[str, Any])-> None:
#     # called when window is closed, typically when the program running in
#     # it exits
#     ...
#
# def on_set_user_var(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     # called when a "user variable" is set or deleted on a window. Here
#     # data will contain key and value
#     ...
#
# def on_title_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     # called when the window title is changed on a window. Here
#     # data will contain title and from_child. from_child will be True
#     # when a title change was requested via escape code from the program
#     # running in the terminal
#     ...
#
# def on_cmd_startstop(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     # called when the shell starts/stops executing a command. Here
#     # data will contain is_start, cmdline and time.
#     ...
#
# def on_color_scheme_preference_change(boss: Boss, window: Window, data: dict[str, Any]) -> None:
#     # called when the color scheme preference of this window changes from
#     # light to dark or vice versa. data contains is_dark and via_escape_code
#     # the latter will be true if the color scheme was changed via escape
#     # code received from the program running in the window
#     ...
