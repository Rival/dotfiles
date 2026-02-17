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
import os
from kitty.boss import get_boss
from kitty.tab_bar import TabBarData, as_rgb
from kitty.window import Window
from typing import Optional, Tuple, Any
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

EXCLUDED_APPS = {'MainThread', 'fastfetch', 'bash', 'sh', 'zsh', 'fish', 'nu'}  # shells omitted from display
LASTSTOP_APPS = {'nvim', 'lazygit'}  # Stop traversal if we encounter these

# Claude process info cache - backend, model, and cwd are stable for a session
_CLAUDE_CACHE: dict[int, tuple[str, str, str, int, float]] = {}
# {tab_id: (backend, model, cwd, pid, timestamp)}
CLAUDE_CACHE_TTL = 60.0  # 60 seconds - Claude session info rarely changes


def _get_claude_from_cache(tab_id: int) -> tuple[str, str, str] | None:
    """Get cached Claude info for tab, or None if expired/not found."""
    import time
    if tab_id not in _CLAUDE_CACHE:
        return None

    backend, model, cwd, pid, timestamp = _CLAUDE_CACHE[tab_id]
    if time.time() - timestamp > CLAUDE_CACHE_TTL:
        del _CLAUDE_CACHE[tab_id]
        return None

    return backend, model, cwd


def _set_claude_cache(tab_id: int, backend: str, model: str, cwd: str, pid: int) -> None:
    """Cache Claude info for tab."""
    import time
    _CLAUDE_CACHE[tab_id] = (backend, model, cwd, pid, time.time())


def get_claude_backend(pid: int) -> str:
    """
    Detect which backend Claude Code is using by checking process environment.

    Returns:
        'zai' for z.ai backend
        'anthropic' for Anthropic backend
        'unknown' if cannot determine
    """
    try:
        proc = psutil.Process(pid)
        env = proc.environ()

        base_url = env.get('ANTHROPIC_BASE_URL', '')
        if 'z.ai' in base_url:
            return 'zai'
        elif 'anthropic.com' in base_url:
            return 'anthropic'

        # Check for other indicators
        if 'ZAI' in env.get('ANTHROPIC_AUTH_TOKEN', ''):
            return 'zai'

        return 'unknown'
    except Exception as e:
        log(f"Error detecting Claude backend: {e}")
        return 'unknown'


def get_claude_backend_from_tab(tab: TabBarData) -> tuple[str, str, str]:
    """
    Get Claude backend, model, and cwd for the given tab.

    This finds the claude process in the tab's process chain
    and checks its environment variables and working directory.

    Uses a 60-second cache to avoid expensive psutil calls.

    Returns:
        Tuple of (backend, model_name, cwd)
        backend: 'zai', 'anthropic', or 'unknown'
        model_name: e.g., 'glm-4.7', 'claude-3.5-sonnet', or 'unknown'
        cwd: Working directory of the Claude process, or empty string
    """
    # Check cache first
    cached = _get_claude_from_cache(tab.tab_id)
    if cached is not None:
        return cached

    boss = get_boss()
    if boss is None:
        return 'unknown', 'unknown', ''

    tab_obj = boss.tab_for_id(tab.tab_id)
    if tab_obj is None or tab_obj.active_window is None:
        return 'unknown', 'unknown', ''

    window = tab_obj.active_window
    if window.child is None:
        return 'unknown', 'unknown', ''

    try:
        # Check foreground_processes for claude
        # We want the LAST claude process (deepest in the tree) as it has correct env vars
        foreground_processes = window.child.foreground_processes
        if foreground_processes:
            last_claude_pid = None
            last_claude_cwd = ''
            # Find all claude processes first
            for proc_info in foreground_processes:
                cmdline = proc_info.get('cmdline', [])
                if cmdline:
                    proc_name = cmdline[0].split('/')[-1]
                    if 'claude' in proc_name.lower():
                        last_claude_pid = proc_info.get('pid')
                        # Get cwd from the process info
                        last_claude_cwd = proc_info.get('cwd', '')

            # Process the last claude process
            if last_claude_pid:
                backend = get_claude_backend(last_claude_pid)
                model = get_claude_model(last_claude_pid, backend)
                log(f"Claude detected: backend={backend}, model={model}, pid={last_claude_pid}, cwd={last_claude_cwd}")
                # Cache the result
                _set_claude_cache(tab.tab_id, backend, model, last_claude_cwd, last_claude_pid)
                return backend, model, last_claude_cwd
    except Exception as e:
        log(f"Error getting Claude backend from tab: {e}")

    return 'unknown', 'unknown', ''


def get_claude_model(pid: int, backend: str = 'unknown') -> str:
    """
    Get the Claude model name from process environment.

    Args:
        pid: Process ID
        backend: Backend type ('zai', 'anthropic', 'unknown') for smart fallback

    Returns:
        Model name like 'glm-4.7', 'claude-3.5-sonnet', or 'unknown'
    """
    try:
        proc = psutil.Process(pid)
        env = proc.environ()

        # Check various possible environment variables
        model = env.get('ANTHROPIC_MODEL') or env.get('MODEL') or env.get('CLAUDE_MODEL')

        if model:
            log(f"Claude model from env: {model}")
            return model

        # Log available env vars for debugging
        env_vars = [k for k in env.keys() if 'MODEL' in k or 'ANTHROPIC' in k]
        if env_vars:
            log(f"Claude env vars available: {env_vars}")

        # Fallback: try to read from config file ONLY for z.ai backend
        if backend == 'zai':
            try:
                import json
                config_path = os.path.expanduser('~/.claude-glm/settings.json')
                if os.path.exists(config_path):
                    with open(config_path) as f:
                        config = json.load(f)
                        if 'env' in config:
                            model = config['env'].get('ANTHROPIC_MODEL', '')
                            if model:
                                log(f"Claude model from config (z.ai): {model}")
                                return model
            except Exception as e:
                log(f"Error reading config: {e}")

        return 'unknown'
    except Exception as e:
        log(f"Error getting Claude model: {e}")
        return 'unknown'

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

import time
import json
from pathlib import Path
from typing import Tuple

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
