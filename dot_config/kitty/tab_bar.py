

# pyright: reportMissingImports=false
import datetime
import sys
import os

import time
from typing import List
from dataclasses import dataclass, field
from typing import Callable
from kitty.boss import get_boss
from kitty.fast_data_types import Screen


from enum import Enum, IntFlag, auto
from kitty.tab_bar import (
    ExtraData,
    Formatter,
    TabBarData,
    DrawData,
    as_rgb,
    draw_attributed_string,
) 

# Add ~/.config/kitty/ to sys.path
config_dir = os.path.expanduser("~/.config/kitty/")
if config_dir not in sys.path:
    sys.path.insert(0, config_dir)
from utils import log, muffle_color, to_grayscale

from utils import (parse_color,
                    shorten_path_progressive,
                    strip_after_delimiter)

# Import tab_apps for modular app configuration
try:
    from tab_apps import load_app_configs, get_app_config, filter_chain_by_apps
    TAB_APPS_AVAILABLE = True
    log("tab_apps module loaded successfully")
except ImportError as e:
    TAB_APPS_AVAILABLE = False
    log(f"tab_apps module not available: {e}")

CALL_COUNTER = 0
CACHE_TTL = 2.0  # 2 seconds
# when tab is opening it may redwaw itself very fast, first draw may contain not valid data
CACHE_UPDATE_SMALLEST_DELTA = 0.1
CACHE_SERIES_UPDATE_MAX_COUNT = 3
CACHE_TAB_UPDATE_MAX_COUNT = 3  # we don't want to update all tabs at once if times passes, so we leave others for next update
tab_current_update_counter = 0



# Configuration
MIN_TAB_WIDTH = 13  # Minimum tab width in characters
MAX_TAB_WIDTH = 40  # Maximum tab width in characters
BAR_DEFAULT_BG = 0  # Default tab background color
TAB_DEFAULT_BG = 0  # Default tab background color
TAB_DEFAULT_FG = parse_color("#FFFFFF")  # Default tab foreground color
TAB_DEFAULT_ACITVE_BG = parse_color("#000000")  # Default tab background color
TAB_DEFAULT_ACTIVE_FG = parse_color("#FF8800")  # Default tab foreground color
DEFAULT_ICON = '❓'

class ChainItemStyle(Enum):
    ICON = 1
    NAME = 2
    CUSTOM = 3


class ChainIconShowWhen(IntFlag):
    ACTIVE    = auto()
    INACTIVE  = auto()

# Example: map apps to icons and colors
@dataclass
class AppMeta:
    icon: str = "❓"
    iconShowStyle = ChainIconShowWhen.ACTIVE | ChainIconShowWhen.INACTIVE
    bg: int = parse_color("#000000")
    fg: int = parse_color("#FFFFFF")
    icon_fg: int = parse_color("#FFFFFF")

# Example: map apps to icons and colors
@dataclass
class TabAdorner:
    left: str = ""
    right: str = "" 

@dataclass
class ChainItemAdorner:
    left: str = ""
    right: str = "" 

# Callback for drawing app item in chain in tab: (app_name, full_chain) → str
DrawCallback = Callable[
    [
        str,
        AppMeta,
        int,
        int,
        DrawData,
        Screen,
        TabBarData,
        int,
        int,
        int,
        bool,
        ExtraData,
    ],
    None,
]
@dataclass
class TabCacheEntry:
    cache_time: float = 0.0
    last_query_time: float = 0.0
    quick_updates_count: int = 0
    draw_chain: List[tuple[str,AppMeta,DrawCallback]] = field(default_factory=list)

chainItemStyle = ChainItemStyle.ICON
chainAdorner = ChainItemAdorner()
tabAdorner = TabAdorner()

tab_caches: dict[int, TabCacheEntry] = {}
timer_id = None
def draw_text(screen: Screen, text:str, color:int):
    screen.cursor.fg = color
    screen.draw(text)

def default_chain_item_draw_callback(
    app_name: str,
    app_meta: AppMeta,
    app_index_in_chain: int,
    chain_length: int,
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> None:
    # Set active/inactive tab colors
    screen.cursor.bg = get_color_for_state(app_meta.bg, tab.is_active)
    # screen.cursor.bg = get_color_for_state2(app_meta.bg, tab.is_active)
        # bg = as_rgb(color_as_int(bg) - 0x101010)  # Slightly darker for inactive tab
    if chainItemStyle == ChainItemStyle.ICON:
        draw_text(screen, app_meta.icon, app_meta.icon_fg)
    elif chainItemStyle == ChainItemStyle.NAME:
        screen.draw(app_name)
    elif chainItemStyle == ChainItemStyle.CUSTOM:
        screen.draw(app_name)
   
    screen.cursor.fg = app_meta.fg
    if app_index_in_chain == chain_length - 1: #if is last
        tab_text = strip_after_delimiter(tab.title)
        tab_text = tab_text.center(MIN_TAB_WIDTH)
        if len(tab_text) > MAX_TAB_WIDTH:
            tab_text = shorten_path_progressive(tab_text,MAX_TAB_WIDTH)
        screen.draw(tab_text)

# Neovim and git callbacks moved to tab_apps/nvim.py and tab_apps/lazygit.py

# def get_app_name(tab: TabBarData) -> str:
#     """Extract the application name from the tab's foreground process."""
#     try:
#         # Get the foreground process name
#         process = tab.active_fg_process or ''
#         # Simplify to the command name (e.g., 'vim' from '/usr/bin/vim')
#         return process.split('/')[-1].lower()
#     except Exception:
#         return 'unknown'

# def calculate_tab_width(screen: Screen, tab: TabBarData, draw_data: DrawData, extra_data: ExtraData) -> int:
#     """Calculate tab width within min and max constraints."""
#     # Estimate width based on title length
#     title = draw_data.default_title(tab, extra_data)
#     char_width = screen.cursor.x  # Approximate width per character
#     estimated_width = len(title) * char_width + 20  # Add padding
#     # Enforce min and max widths
#     return max(MIN_TAB_WIDTH, min(MAX_TAB_WIDTH, estimated_width))


def get_draw_chain(proc_chain: list[str]) -> list[tuple[str,AppMeta,DrawCallback]]:
    """
    Convert process chain to draw chain with AppMeta and callbacks.
    Uses tab_apps modular config if available, otherwise falls back to APP_META.
    """
    # Import locally to avoid binding issues
    try:
        from tab_apps import get_app_config as _get_app_config
    except ImportError:
        _get_app_config = None

    result = []
    for proc_name in proc_chain:
        meta = None
        callback = None

        # Try tab_apps modular config first
        if TAB_APPS_AVAILABLE and _get_app_config is not None:
            config = _get_app_config(proc_name)
            if config is not None:
                meta = config.to_app_meta()
                callback = config.draw_callback or default_chain_item_draw_callback

        # Default for unknown apps
        if meta is None:
            meta = AppMeta(
                icon='❓',
                bg=TAB_DEFAULT_BG,
                fg=TAB_DEFAULT_FG,
                icon_fg=TAB_DEFAULT_FG
            )
            callback = default_chain_item_draw_callback

        result.append((proc_name, meta, callback))
    return result

def get_color_for_state(color:int, is_active:bool) -> int:
    if is_active:
        return color
    else:
        return to_grayscale(color)

def draw_simple_tab_title(draw_data: DrawData, screen: Screen, tab: TabBarData) -> None:
    """Draw a simple tab with roundings when process chain is empty."""
    title = strip_after_delimiter(tab.title)
    title = title.center(MIN_TAB_WIDTH)
    if len(title) > MAX_TAB_WIDTH:
        title = shorten_path_progressive(title, MAX_TAB_WIDTH)

    # Set colors
    bg_color = TAB_DEFAULT_ACITVE_BG if tab.is_active else TAB_DEFAULT_BG
    fg_color = TAB_DEFAULT_ACTIVE_FG if tab.is_active else TAB_DEFAULT_FG

    # Draw left adorner
    screen.cursor.bg = BAR_DEFAULT_BG
    screen.cursor.fg = bg_color
    screen.draw(tabAdorner.left)

    # Draw title
    screen.cursor.bg = bg_color
    screen.cursor.fg = fg_color
    screen.draw(title)

    # Draw right adorner
    screen.cursor.bg = BAR_DEFAULT_BG
    screen.cursor.fg = bg_color
    screen.draw(tabAdorner.right)

#drawing tab like chains of apps: 🦆 > 🐉 .../path/foo.lua
def draw_chain_tab(
    proc_chain: list[tuple[str,AppMeta,DrawCallback]],
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
    delimiter: str = ">"
) -> None:
    chain_length = len(proc_chain)
    lastAppMeta = AppMeta()
    for i, (app_name, app_meta, draw_callback) in enumerate(proc_chain):
        # if tab.is_active:
        if  (i == 0):#drawing left adorner of tab
            screen.cursor.bg = BAR_DEFAULT_BG
            screen.cursor.fg = get_color_for_state(app_meta.bg, tab.is_active)
            screen.draw(tabAdorner.left)
        else:#drawing left ear of chain item
            screen.cursor.bg = get_color_for_state(lastAppMeta.bg, tab.is_active)            
            screen.cursor.fg = get_color_for_state(app_meta.bg, tab.is_active)            
            screen.draw(chainAdorner.left)

        draw_callback(
            app_name,
            app_meta,           # or pass the label or process name if you have it
            i,
            chain_length,
            draw_data,          # fill as needed
            screen,
            tab,                # fill as needed
            before,
            max_title_length,
            index,
            is_last,
            extra_data          # fill as needed
        )

        lastAppMeta = app_meta

    #drawing right adorner of tab
    screen.cursor.bg = BAR_DEFAULT_BG
    screen.cursor.fg = get_color_for_state(lastAppMeta.bg, tab.is_active)
    screen.draw(tabAdorner.right)

def draw_simple_tab(
    proc_chain: list[tuple[str,AppMeta,DrawCallback]],
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
    delimiter: str = ">"
) -> None:
    chain_length = len(proc_chain)
    (app_name, app_meta, draw_callback) = proc_chain[-1]
    #drawing left adorner of tab
    # screen.cursor.bg = 0
    # screen.cursor.fg = app_meta.bg
    # screen.draw(tabAdorner.left)
    draw_callback(
            app_name,
            app_meta,           # or pass the label or process name if you have it
            0,
            1,
            draw_data,          # fill as needed
            screen,
            tab,                # fill as needed
            before,
            max_title_length,
            index,
            is_last,
            extra_data          # fill as needed
        )

    # tab_text =strip_after_delimiter(tab.title)
    # tab_text = tab_text.center(MIN_TAB_WIDTH)
    # screen.cursor.bg = TAB_DEFAULT_BG
    # screen.cursor.fg = TAB_DEFAULT_FG
    # screen.draw(tab_text)
    # screen.cursor.bg = 0
    # screen.cursor.fg = app_meta.bg
    # screen.draw(tabAdorner.right)
EXCLUDED_APPS = {'MainThread', 'fastfetch', 'file', 'bash', 'sh', 'zsh', 'fish'}  # shells omitted from display (nu/nushell is user's main shell)
LASTSTOP_APPS = {'nvim', 'lazygit'}  # Stop traversal if we encounter these

# # Easy cleanup when tabs are deleted
# def cleanup_deleted_tabs():
#     active_tab_ids = {tab.id for tab in get_all_active_tabs()}
#     deleted_ids = set(tab_cache.keys()) - active_tab_ids
#     for tab_id in deleted_ids:
#         del tab_cache[tab_id]

def get_process_chain_for_tab_fixed(tab: TabBarData) ->  List[tuple[str,AppMeta,DrawCallback]]:
    """
    Get process chain using kitty's built-in foreground_processes data.
    This is much faster than psutil since kitty already tracks this information.
    """
    global last_cache_time, tab_caches, tab_cache_times, tab_current_update_counter
    boss = get_boss()
    if boss is None:
        return []
    
    tab_obj = boss.tab_for_id(tab.tab_id)
    if tab_obj is None or tab_obj.active_window is None:
        return []
    
    window = tab_obj.active_window
    if window.child is None:
        return []
    
    cache_key = tab.tab_id
    current_time = time.time()

    # Check if we have valid cached data
    if cache_key in tab_caches:
        tab_cache = tab_caches[cache_key]  # Remove semicolon
        elapsed = current_time - tab_cache.cache_time
        last_query_time = tab_cache.last_query_time  # Fix typo
        elapsed_since_query = current_time - last_query_time
        
        # Update query time
        tab_cache.last_query_time = current_time
        
        # Track quick updates
        if elapsed_since_query < CACHE_UPDATE_SMALLEST_DELTA:
            tab_cache.quick_updates_count += 1  # Fix: was =+1
        else:
            tab_cache.quick_updates_count = 0
        
        # No need to reassign: tab_caches[cache_key] = tab_cache
        # (we're modifying the same object in-place)
        
        # Check if cache is still valid
        if elapsed < CACHE_TTL:
            # Cache is fresh, but check if we're querying too frequently
            if tab.is_active == False or tab_cache.quick_updates_count < CACHE_SERIES_UPDATE_MAX_COUNT:
                log(f"CACHE tab {cache_key}: HIT elapsed:{elapsed_since_query:.3f} "
                    f"quick_updates:{tab_cache.quick_updates_count}")
                return tab_cache.draw_chain
            else:
                log(f"CACHE tab {cache_key}: REFRESH -- too many quick queries "
                    f"elapsed:{elapsed_since_query:.3f} quick_updates:{tab_cache.quick_updates_count}")
                # Fall through to refresh cache
        elif tab_current_update_counter >= CACHE_TAB_UPDATE_MAX_COUNT:
            # Cache is stale but too many tabs are updating, use stale data
            log(f"CACHE tab {cache_key}: HIT -- cache stale but too many tabs updating "
                f"elapsed:{elapsed:.3f} quick_updates:{tab_cache.quick_updates_count}")
            return tab_cache.draw_chain
        # Fall through to refresh cache
    else:
        log(f"CACHE tab {cache_key}: MISS")
        # Fall through to refresh cache

    # Refresh cache (common path for all cache miss/refresh cases)
    log(f"CACHE tab {cache_key}: REFRESHING")

    tab_current_update_counter += 1
    # Cache miss - get fresh data
    foreground_processes = window.child.foreground_processes
    
    # Process the data (extract process names)
    app_stack_names = []
    seen = set()
    if foreground_processes:
        for process_info in foreground_processes:
            # Extract process name from cmdline
            cmdline = process_info.get('cmdline', [])
            if not cmdline:
                continue
                
            # Get the executable name (last part of path)
            process_name = cmdline[0].split('/')[-1]
            
            # # Apply filtering logic
            if process_name not in EXCLUDED_APPS and process_name not in seen:
                app_stack_names.append(process_name)
                seen.add(process_name)
            #
            # Stop if we hit a terminal app
            if process_name in LASTSTOP_APPS:
                break
    
    # Cache the processed data, not the raw foreground_processes
    if len(app_stack_names) != 0:
        # Filter out leading shells - find first non-shell and start from there
        SHELLS = {'bash', 'sh', 'zsh', 'fish', 'nu'}
        first_main_idx = 0
        for i, name in enumerate(app_stack_names):
            if name not in SHELLS:
                first_main_idx = i
                break
        app_stack_names = app_stack_names[first_main_idx:]

        # Apply per-app filtering rules from tab_apps if available
        if TAB_APPS_AVAILABLE:
            try:
                from tab_apps import filter_chain_by_apps as _filter_chain_by_apps
                app_stack_names = _filter_chain_by_apps(app_stack_names, start_from_first_non_shell=False)
            except ImportError:
                pass  # Fall back to unfiltered chain

        app_stack_infos = get_draw_chain(app_stack_names)
        tab_caches[cache_key] = TabCacheEntry(current_time, current_time, 1, app_stack_infos)
        log(f"tab.id:{tab.tab_id} window:{window.is_focused} chain:{' ,'.join(app_stack_names)}")
        return app_stack_infos

    # Clear cache for this tab to force refresh
    if cache_key in tab_caches:
        del tab_caches[cache_key]

    log(f"ZERO DATA tab.id:{tab.tab_id} window:{window.is_focused} chain:{' ,'.join(app_stack_names)} cmdline:{' ,'.join(foreground_processes)}")
    return []

def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global tab_current_update_counter
    app_draw_chain_info = get_process_chain_for_tab_fixed(tab)
    # processName = get_foreground_app_from_chain(app_chain);
    # app_chain_with_cmds = get_process_chain_for_tab_withcmdline(tab)
    # tab_manager = get_boss().active_tab_manager
    # if tab_manager is not None:
    #     window = tab_manager.active_window
    #     if window is not None:
    #         cwd = window.cwd_of_child
    #
    # boss = get_boss()
    # tab_obj = boss.tab_for_id(tab.tab_id)

    # path = os.path.basename((tab_obj.get_exe_of_active_window(oldest=True) if tab else '') or '')
    # log(f"SCRIPT_ID:{SCRIPT_ID}")
    # log(f"tab.title:{tab.title} cwd:{cwd} processName:{processName} chain:{' ,'.join(app_chain)}")
    # CALL_COUNTER +=1
    # log(f"tab.title:{tab.title} PPPP:{path} cwd:{cwd} processName:{processName} chain:{' ,'.join(app_chain)}")
    # return draw_tab_with_powerline(
    #         draw_data, screen, tab, before, max_title_length, index, is_last, extra_data
    #     )
    # if tab.is_active:

    # If chain is empty, show a simple tab with title
    if not app_draw_chain_info:
        draw_simple_tab_title(draw_data, screen, tab)
    else:
        draw_chain_tab(app_draw_chain_info,draw_data,screen,tab,before,max_title_length,index,is_last,extra_data)

    # else:
    #     draw_simple_tab(app_draw_chain_info,draw_data,screen,tab,before,max_title_length,index,is_last,extra_data)


    if is_last:
        tab_current_update_counter = 0
    #     # ta = TabAccessor(tab.tab_id)
    #     log(
    #         f"tab.last_exe:{path} cwd:{cwd} processName:{processName} "
    #         f"chain:{' ,'.join(f'{name} ({cmd})' for name, cmd in app_chain_with_cmds)}"
    #         )
        # log(f"tab.title:{tab.title} cwd:{cwd} processName:{processName} chain:{' ,'.join(app_chain)}")
        # notify_send(tab.title)


    # return screen.cursor.x

    # #     timer_id = add_timer(_redraw_tab_bar, 2.0, True)
    # draw_tab_with_powerline(
    #     draw_data, screen, tab, before, max_title_length, index, is_last, extra_data
    # )
    # if is_last:
    #     draw_right_status(draw_data, screen)
    return screen.cursor.x


def draw_right_status(draw_data: DrawData, screen: Screen) -> None:
    # The tabs may have left some formats enabled. Disable them now.
    draw_attributed_string(Formatter.reset, screen)
    cells = create_cells()
    # Drop cells that wont fit
    while True:
        if not cells:
            return
        padding = screen.columns - screen.cursor.x - sum(len(c) + 3 for c in cells)
        if padding >= 0:
            break
        cells = cells[1:]

    if padding:
        screen.draw(" " * padding)

    tab_bg = as_rgb(int(draw_data.inactive_bg))
    tab_fg = as_rgb(int(draw_data.inactive_fg))
    default_bg = as_rgb(int(draw_data.default_bg))
    for cell in cells:
        # Draw the separator
        if cell == cells[0]:
            screen.cursor.fg = tab_bg
            screen.draw("")
        else:
            screen.cursor.fg = default_bg
            screen.cursor.bg = tab_bg
            screen.draw("")
        screen.cursor.fg = tab_fg
        screen.cursor.bg = tab_bg
        screen.draw(f" {cell} ")


def create_cells() -> list[str]:
    now = datetime.datetime.now()
    return [
        # get_laptop_battery_status(),
        now.strftime("%A %d %b"),
        now.strftime("%H:%M"),
    ]

# def get_laptop_battery_status():
#     try:
#         output = subprocess.getoutput("acpi -b")
#         if not output:
#             return ""
#         parts = output.split(", ")
#         if len(parts) >= 2:
#             percentage = parts[1].strip()
#             return f" {percentage}"
#     except Exception:
#         pass
#     return ""




# def _redraw_tab_bar(timer_id):
#     for tm in get_boss().all_tab_managers:
#         tm.mark_tab_bar_dirty()
