# pyright: reportMissingImports=false
import logging

# Configure logging once at the top of your script
logging.basicConfig(
    filename='/tmp/kitty_script.log',  # Or wherever you want
    level=logging.DEBUG,               # DEBUG, INFO, WARNING, etc.
    format='%(asctime)s [%(levelname)s] %(message)s',
) 
def log(msg):
    logging.debug(msg)

import subprocess
import psutil
from typing import Any
import os
from kitty.boss import get_boss
from kitty.tab_bar import TabBarData
from kitty.boss import Boss
from kitty.window import Window
from kitty.utils import color_as_int
from kitty.tab_bar import (DrawData, ExtraData, Formatter, TabBarData, as_rgb, draw_attributed_string, draw_tab_with_powerline)
from typing import Optional, Dict, Any
def parse_color(value:str)-> int:
        return as_rgb(int(value[1:], 16))

def get_process_name(window: Window) -> str:
    pid = window.child.pid
    # Get the shell process (likely Nushell)
    shell_process = psutil.Process(pid)
    # Check child processes for the foreground app
    for child in shell_process.children(recursive=True):
        cmdline = child.cmdline()
        if cmdline:  # Ensure cmdline is not empty
            cmd = cmdline[0].split('/')[-1]  # Get the executable name
            return cmd
    return ''

def get_window_from_tab(tab: TabBarData):
    """
    Get the window object associated with a tab.
    
    Args:
        tab: TabBarData object
        
    Returns:
        Window object or None
    """
    try:
        boss = get_boss()
        if not boss:
            return None
            
        # Method 1: Through active tab manager
        tm = boss.active_tab_manager
        if tm:
            # Get the actual tab object (not TabBarData)
            for actual_tab in tm.tabs:
                if actual_tab.id == tab.tab_id:
                    return actual_tab.active_window
        
        # Method 2: Through all tab managers
        for tm in boss.all_tab_managers:
            for actual_tab in tm.tabs:
                if actual_tab.id == tab.tab_id:
                    return actual_tab.active_window
                    
        return None
        
    except Exception as e:
        print(f"Error getting window from tab: {e}")
        return None

def get_window_id_from_tab(tab: TabBarData) -> Optional[str]:
    """
    Get the window ID from a tab.
    
    Args:
        tab: TabBarData object
        
    Returns:
        Window ID as string or None
    """
    try:
        window = get_window_from_tab(tab)
        if window:
            return str(window.id)
        return None
        
    except Exception as e:
        print(f"Error getting window ID: {e}")
        return None
# powerline_symbols: dict[PowerlineStyle, tuple[str, str]] = {
#     'slanted': ('', '╱'),
#     'round': ('', '')
# }SEPARATOR_SYMBOL, SOFT_SEPARATOR_SYMBOL = ("", "")
# separator_symbol, soft_separator_symbol = powerline_symbols.get(draw_data.powerline_style, ('', ''))
# LEFT_SEP = ""
# RIGHT_SEP = ""
# screen.draw("")
# screen.draw("")

EXCLUDED_APPS = {'MainThread', 'fastfetch'}  # this apps are omitted analyzing chain of apps
LASTSTOP_APPS = {'nvim', 'lazygit'}  # Stop traversal if we encounter these

def strip_after_delimiter(s: str, delimiter: str = '>') -> str:
    return s.partition(delimiter)[0].strip()

def get_process_chain(window: Window) -> list[str]:
    try:
        pid = window.child.pid
        proc = psutil.Process(pid)
        
        chain = []
        seen = set()

        while True:
            name = proc.name()
            if name not in EXCLUDED_APPS and name not in seen:
                chain.append(name)
                seen.add(name)

            if name in LASTSTOP_APPS:
                break  # Stop following children

            children = proc.children()
            if not children:
                break
            proc = sorted(children, key=lambda p: p.create_time())[0]

        return chain
    except Exception as e:
        return [f"error: {e}"]

def get_process_chain_for_tab(tab: TabBarData) -> list[str]:
    boss = get_boss()
    if boss is None:
        return []
    tab_obj = boss.tab_for_id(tab.tab_id)
    if tab_obj is None or tab_obj.active_window is None:
        return []

    window = tab_obj.active_window
    if window.child is None:
        return []

    try:
        pid = window.child.pid
        proc = psutil.Process(pid)
        chain = []
        seen = set()

        while True:
            name = proc.name()
            if name not in EXCLUDED_APPS and name not in seen:
                chain.append(name)
                seen.add(name)

            if name in LASTSTOP_APPS:
                break

            children = proc.children()
            if not children:
                break

            # Follow the oldest child (likely the next in the chain)
            proc = sorted(children, key=lambda p: p.create_time())[0]

        return chain
    except Exception as e:
        return [f"error: {e}"]

def get_process_chain_for_tab_withcmdline(tab: TabBarData) -> list[str]:
    boss = get_boss()
    if boss is None:
        return []
    tab_obj = boss.tab_for_id(tab.tab_id)
    if tab_obj is None or tab_obj.active_window is None:
        return []

    window = tab_obj.active_window
    if window.child is None:
        return []

    try:
        pid = window.child.pid
        proc = psutil.Process(pid)
        chain = []
        seen = set()

        while True:
            name = proc.name()
            if name not in EXCLUDED_APPS and name not in seen:
                cmdline = ' '.join(proc.cmdline()) or '[no cmdline]'
                chain.append((name, cmdline))
                seen.add(name)

            if name in LASTSTOP_APPS:
                break

            children = proc.children()
            if not children:
                break

            # Follow the oldest child (likely the next in the chain)
            proc = sorted(children, key=lambda p: p.create_time())[0]

        return chain
    except Exception as e:
        return [f"error: {e}"]

def get_foreground_app(window: Window) -> str:
    chain = get_process_chain(window)
    return chain[-1] if chain else ''

def get_foreground_app_from_chain(chain: list[str]) -> str:
    return chain[-1] if chain else ''

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

def muffle_color(color: int, factor: float = 0.5) -> int:
    """
    Muffle a color by reducing saturation.
    
    Args:
        color: RGB color as integer from as_rgb()
        factor: 0.0 = full grayscale, 1.0 = original color
    
    Returns:
        Muffled color as as_rgb() integer
    """
    # Extract RGB components from as_rgb format
    r = (color >> 16) & 0xFF
    g = (color >> 8) & 0xFF  
    b = color & 0xFF
    
    # Calculate grayscale using luminance weights
    gray = int(0.299 * r + 0.587 * g + 0.114 * b)
    
    # Interpolate between grayscale and original
    new_r = int(gray + (r - gray) * factor)
    new_g = int(gray + (g - gray) * factor) 
    new_b = int(gray + (b - gray) * factor)
    
    # Return in same format as as_rgb()
    return as_rgb((new_r << 16) | (new_g << 8) | new_b)

def to_grayscale(color: int) -> int:
    """Convert color to pure grayscale."""
    return muffle_color(color, 0.0)

import hashlib
import time
import json
from pathlib import Path
from typing import Optional, Dict, Any, Tuple

class FileCache:
    def __init__(self, cache_dir: str = "/tmp/kitty_tab_cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
        self.cache_ttl = 5.0  # Cache TTL in seconds

    def _get_cache_key(self, cwd: str, tab_id: int) -> str:
        """Generate cache key based on working directory and tab ID"""
        key_data = f"{cwd}:{tab_id}"
        return hashlib.md5(key_data.encode()).hexdigest()

    def _get_cache_file(self, cache_key: str) -> Path:
        return self.cache_dir / f"tab_{cache_key}.json"

    def _should_invalidate(self, cwd: str, cached_data: Dict) -> bool:
        """Check if cache should be invalidated based on directory changes"""
        try:
            # Check if git HEAD changed (most common case)
            git_head_file = Path(cwd) / ".git" / "HEAD"
            if git_head_file.exists():
                current_head = git_head_file.read_text().strip()
                if current_head != cached_data.get("git_head"):
                    return True

            # Check if working directory changed
            if cwd != cached_data.get("cwd"):
                return True

            return False
        except:
            return True  # Invalidate on any error

    def get(self, cwd: str, tab_id: int) -> Optional[Dict[str, Any]]:
        """Get cached data if valid"""
        try:
            cache_key = self._get_cache_key(cwd, tab_id)
            cache_file = self._get_cache_file(cache_key)

            if not cache_file.exists():
                return None

            # Check if cache is too old
            if time.time() - cache_file.stat().st_mtime > self.cache_ttl:
                cache_file.unlink()
                return None

            cached_data = json.loads(cache_file.read_text())

            # Check if cache should be invalidated
            if self._should_invalidate(cwd, cached_data):
                cache_file.unlink()
                return None

            return cached_data
        except:
            return None

    def set(self, cwd: str, tab_id: int, data: Dict[str, Any]) -> None:
        """Cache data with metadata"""
        try:
            cache_key = self._get_cache_key(cwd, tab_id)
            cache_file = self._get_cache_file(cache_key)

            # Add metadata for invalidation
            try:
                git_head_file = Path(cwd) / ".git" / "HEAD"
                git_head = git_head_file.read_text().strip() if git_head_file.exists() else ""
            except:
                git_head = ""

            cache_data = {
                **data,
                "cwd": cwd,
                "git_head": git_head,
                "timestamp": time.time()
            }

            cache_file.write_text(json.dumps(cache_data))
        except:
            pass  # Silently fail on cache write errors

def get_git_info_fast(cwd: str) -> Tuple[str, str]:
    """
    Fast git info retrieval that checks files directly when possible
    """
    if not cwd:
        return "", ""
    
    try:
        git_dir = Path(cwd)
        
        # Walk up to find .git directory
        while git_dir != git_dir.parent:
            git_path = git_dir / ".git"
            if git_path.exists():
                break
            git_dir = git_dir.parent
        else:
            return "", ""  # No git repo found
        
        repo_name = git_dir.name
        
        # Try to read branch from .git/HEAD directly (fastest)
        try:
            head_file = git_path / "HEAD"
            if head_file.exists():
                head_content = head_file.read_text().strip()
                if head_content.startswith("ref: refs/heads/"):
                    branch = head_content[16:]  # Remove "ref: refs/heads/"
                    return repo_name, branch
        except:
            pass
        
        # Fallback to git command (slower but more reliable)
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                cwd=str(git_dir),
                capture_output=True,
                text=True,
                timeout=0.5  # Very short timeout
            )
            branch = result.stdout.strip() if result.returncode == 0 else ""
            return repo_name, branch
        except:
            return repo_name, ""
            
    except:
        return "", ""


# Simple file cache - one file per OS window
class SimpleFileCache:
    def __init__(self):
        self.cache_dir = "/tmp/kitty_cache"
        os.makedirs(self.cache_dir, exist_ok=True)
        self.os_window_id = None
        self._cache_data = None
        self._cache_file = None
        self._last_load_time = 0
    
    def get_os_window_id(self):
        """Get current OS window ID"""
        if self.os_window_id is None:
            try:
                from kitty.boss import get_boss
                boss = get_boss()
                if boss and boss.active_os_window:
                    self.os_window_id = boss.active_os_window.id
                else:
                    self.os_window_id = "unknown"
            except:
                self.os_window_id = "unknown"
        return self.os_window_id
    
    def get_cache_file_path(self) -> str:
        """Get cache file path for this OS window"""
        if self._cache_file is None:
            os_window_id = self.get_os_window_id()
            self._cache_file = f"{self.cache_dir}/window_{os_window_id}.json"
        return self._cache_file
    
    def load_cache_file(self) -> dict:
        """Load entire cache file into memory"""
        cache_file = self.get_cache_file_path()
        
        # Check if we need to reload
        try:
            file_mtime = os.path.getmtime(cache_file)
            if file_mtime > self._last_load_time:
                with open(cache_file, 'r') as f:
                    self._cache_data = json.load(f)
                    self._last_load_time = file_mtime
        except:
            self._cache_data = {}
        
        return self._cache_data or {}
    
    def save_cache_file(self, cache_data: dict) -> None:
        """Save entire cache file"""
        try:
            cache_file = self.get_cache_file_path()
            with open(cache_file, 'w') as f:
                json.dump(cache_data, f)
            self._cache_data = cache_data
            self._last_load_time = time.time()
        except:
            pass
    
    def set(self, key: str, value: Any) -> None:
        """Set a value in the cache"""
        cache_data = self.load_cache_file()
        cache_data[key] = {
            'data': value,
            'time': time.time()
        }
        self.save_cache_file(cache_data)
    
    def get(self, key: str, max_age: float = 2.0) -> Optional[Any]:
        """Get a value from the cache"""
        cache_data = self.load_cache_file()
        
        if key not in cache_data:
            return None
        
        entry = cache_data[key]
        if time.time() - entry.get('time', 0) > max_age:
            # Remove expired entry
            del cache_data[key]
            self.save_cache_file(cache_data)
            return None
        
        return entry.get('data')

# path shortening
def shorten_path_progressive(path, max_length, min_chars_per_segment=1):
    segments = path.split('/')
    
    # Start with full path
    current_path = path
    
    # Progressive shortening: reduce each segment incrementally
    while len(current_path) > max_length and can_shorten_more(segments, min_chars_per_segment):
        # Find the longest segment that can still be shortened
        target_segment = find_longest_shortenable_segment(segments, min_chars_per_segment)
        
        if target_segment is not None:
            # Reduce by one character
            segments[target_segment] = segments[target_segment][:-1]
            current_path = '/'.join(segments)
        else:
            break
    
    return current_path

def find_longest_shortenable_segment(segments, min_chars):
    longest_idx = None
    longest_len = 0
    
    for i, segment in enumerate(segments):
        # Skip root (~) and final segment (usually most important)
        if i == 0 or i == len(segments) - 1:
            continue
            
        # Only consider segments that can be shortened further
        if len(segment) > min_chars and len(segment) > longest_len:
            longest_idx = i
            longest_len = len(segment)
    
    return longest_idx

def can_shorten_more(segments, min_chars):
    for i, segment in enumerate(segments[1:-1], 1):  # Skip first and last
        if len(segment) > min_chars:
            return True
    return False
