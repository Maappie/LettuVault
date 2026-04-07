import sys
import os
import time
import subprocess
import threading
import atexit
from collections import deque
from rich.live import Live
from rich.layout import Layout
from rich.panel import Panel
from rich.console import Console
from rich.table import Table
from rich.text import Text
if os.name == 'nt':
    import msvcrt
else:
    import sys as _sys
    import select
    import tty
    import termios

# Configuration
LOG_LIMIT = 100 

from lettu_backend.core.config import PROJECT_ROOT

# Detect the local .venv python for this project—CRITICAL FOR OS-SPECIFIC CONFLICTS
if os.name == 'nt':
    venv_python = os.path.join(PROJECT_ROOT, ".venv", "Scripts", "python.exe")
else:
    venv_python = os.path.join(PROJECT_ROOT, ".venv", "bin", "python")
python_exe = venv_python if os.path.exists(venv_python) else sys.executable

def sweep_zombies():
    """Aggressively kills any existing LettuVault processes before starting, excluding current PID."""
    my_pid = os.getpid()
    keywords = ["lettu_backend", "lettu_vault_ai", "uvicorn", "broker_service"]
    print(f"[SEARCH] Sweeping for zombie processes (Excluding my PID: {my_pid})...")
    
    try:
        import psutil
        for p in psutil.process_iter(['pid', 'cmdline']):
            if p.pid == my_pid:
                continue
            cmdline = p.info.get('cmdline')
            if cmdline:
                cmd_str = ' '.join(cmdline).lower()
                # Exclude the current log_hub process itself from accidental matches
                if "sweep" in cmd_str or "log_hub" in cmd_str:
                    continue
                if any(kw in cmd_str for kw in keywords):
                    try:
                        p.terminate()
                        print(f"🧹 [ZOMBIE KILLER] Terminated old process PID: {p.pid}")
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
        time.sleep(1) # Wait for OS to cleanup
    except ImportError:
        print("[WARN] psutil not found, skipping deep zombie sweep.")
        
    print("[OK] System swept. Starting fresh.")

def free_port(port):
    """Safely frees the port before starting, ignoring critical Windows System PIDs."""
    if os.name == 'nt':
        try:
            # We want to be specific here to avoid killing the wrong thing
            output = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True).decode()
            for line in output.strip().split('\n'):
                if f":{port}" in line and "LISTENING" in line:
                    parts = line.strip().split()
                    pid = parts[-1]
                    if pid != '0' and pid != '4': # Avoid System/Idle
                        subprocess.run(['taskkill', '/F', '/T', '/PID', pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        time.sleep(0.5)
                    break
        except subprocess.CalledProcessError:
            pass 
        except Exception:
            pass

class LogHub:
    SERVICES = {
        "BROKER": {
            "cmd": [python_exe, "-m", "lettu_backend.services.broker_service"],
            "color": "yellow",
            "desc": "Central MQTT Hub"
        },
        "API SERVER": {
            "cmd": [python_exe, "-m", "uvicorn", "lettu_backend.main:app", "--host", os.getenv("API_HOST", "0.0.0.0"), "--port", str(os.getenv("API_PORT", "8000")), "--reload"],
            "color": "green",
            "desc": "Main Backend & Web"
        },
        "SUBSCRIBERS": {
            "cmd": [python_exe, "-m", "lettu_backend.services.mqtt"],
            "color": "cyan",
            "desc": "DB Storage"
        },
        "PUBLISHERS": {
            "cmd": [python_exe, "-m", "lettu_vault_ai.predict"],
            "color": "magenta",
            "desc": "AI Detector"
        },
        "MOBILE_APP": {
            "cmd": ["flutter", "run"],
            "color": "blue",
            "desc": "Flutter Mobile App"
        }
    }

    def __init__(self, include_mobile=False):
        self.include_mobile = include_mobile
        # Define the basic service set
        active_services = ["BROKER", "API SERVER", "SUBSCRIBERS", "PUBLISHERS"]
        if self.include_mobile:
            active_services.append("MOBILE_APP")
            
        self.selected_index = 0
        self.service_names = active_services
        self.running = True
        self.console = Console()
        self.logs = {name: deque(maxlen=LOG_LIMIT) for name in self.service_names}
        self.processes = {} 
        self.is_headless = not sys.stdin.isatty()
        os.makedirs("data", exist_ok=True)
        
        # Register the cleanup function to run even if the terminal window is closed abruptly
        atexit.register(self.stop_all_services)

    def capture_logs(self, name):
        service_cfg = self.SERVICES.get(name)
        if not service_cfg:
            return

        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONPATH"] = os.path.abspath(os.curdir) + os.pathsep + env.get("PYTHONPATH", "")

        # Special case for mobile: must run inside the mobile subdirectory
        cwd = os.path.abspath(os.curdir)
        if name == "MOBILE_APP":
            # Attempt to locate the mobile directory
            potential_path = os.path.join(cwd, "mobile", "LettuVault_Unfinished")
            if os.path.exists(potential_path):
                cwd = potential_path

        while self.running:
            try:
                msg = f"🔄 [SYSTEM] Starting {name}..."
                self.logs[name].append(msg)
                if getattr(self, "is_headless", False): print(f"[{name}] {msg}", flush=True)
                
                proc = subprocess.Popen(
                    service_cfg["cmd"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    env=env,
                    cwd=cwd,
                    bufsize=1,
                    encoding='utf-8',
                    errors='replace',
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
                )
                self.processes[name] = proc
                
                for line in iter(proc.stdout.readline, ""):
                    if not self.running: break
                    clean_line = "".join(ch for ch in line if ch.isprintable() or ch in "\n\r\t")
                    stripped = clean_line.strip()
                    
                    if stripped and not any(x in stripped for x in ["DeprecationWarning", "warn(", "Use `plugin`"]):
                        self.logs[name].append(stripped)
                        if getattr(self, "is_headless", False):
                            print(f"[{name}] {stripped}", flush=True)
                
                if not self.running:
                    break
                
                exit_code = proc.poll()
                msg = f"⚠️ [SYSTEM] {name} stopped (Code: {exit_code}). Restarting in 3s..."
                self.logs[name].append(msg)
                if getattr(self, "is_headless", False): print(f"[{name}] {msg}", flush=True)
                time.sleep(3) 
                
            except Exception as e:
                if not self.running: break
                msg = f"❌ [SYSTEM] Error in {name}: {str(e)}. Retrying in 5s..."
                self.logs[name].append(msg)
                if getattr(self, "is_headless", False): print(f"[{name}] {msg}", flush=True)
                time.sleep(5)

    def stop_all_services(self):
        """Forcefully stop all running background processes."""
        if not self.processes: return # Already cleaned up
        
        self.running = False
        print("\nStopping background services...")
        for name, proc in self.processes.items():
            if proc.poll() is None:
                try:
                    if os.name == 'nt':
                        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)], 
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    else:
                        proc.terminate()
                except Exception:
                    pass
        self.processes.clear() # Clear the dict so atexit doesn't run it twice
        print("✅ All systems stopped.")

    def make_layout(self):
        layout = Layout()
        layout.split_row(
            Layout(name="menu", size=22),
            Layout(name="main")
        )
        return layout

    def generate_menu(self):
        table = Table(show_header=False, box=None, padding=(0,1))
        for i, name in enumerate(self.service_names):
            if i == self.selected_index:
                table.add_row(Text(f" > {name} ", style="bold black on green"))
            else:
                table.add_row(Text(f"   {name} ", style="dim white"))
        return Panel(table, title="SYSTEMS", border_style="blue")

    def generate_logs(self):
        name = self.service_names[self.selected_index]
        service_cfg = self.SERVICES[name]
        log_text = Text()
        
        # Detect terminal height to handle scrolling
        try:
            _, term_height = os.get_terminal_size()
            # Reserve some lines for headers/padding
            max_lines = max(5, term_height - 6) 
        except:
            max_lines = 25

        try:
            # Show the LATEST lines that fit the screen
            visible_logs = list(self.logs[name])[-max_lines:]
        except RuntimeError:
            return Panel("Rerendering...", title=f"📡 {name}", border_style=service_cfg["color"])
            
        for log in visible_logs:
            # Trim long lines to prevent wrapping from stealing vertical space
            trimmed_log = log if len(log) < 100 else log[:97] + "..."
            log_text.append(f"{trimmed_log}\n", style=service_cfg["color"])
        
        return Panel(
            log_text, 
            title=f"📡 {name} ({service_cfg['desc']})", 
            subtitle="Switch: j/k | Quit: q",
            border_style=service_cfg["color"],
            padding=(0, 1)
        )

    def run(self):
        threading.Thread(target=self.capture_logs, args=("BROKER",), daemon=True).start()
        time.sleep(1) 
        
        other_services = ["API SERVER", "SUBSCRIBERS", "PUBLISHERS"]
        if self.include_mobile:
            other_services.append("MOBILE_APP")

        for name in other_services:
            threading.Thread(target=self.capture_logs, args=(name,), daemon=True).start()
            time.sleep(0.3)

        if getattr(self, "is_headless", False):
            print("\n[SYSTEM] Headless mode detected. TUI bypassed. Services running continuously in background...")
            try:
                while self.running:
                    time.sleep(1)
            finally:
                self.stop_all_services()
            return

        layout = self.make_layout()
        old_settings = None
        try:
            # On Linux, set terminal to cbreak mode for non-blocking key reads
            if os.name != 'nt':
                old_settings = termios.tcgetattr(_sys.stdin)
                tty.setcbreak(_sys.stdin.fileno())

            with Live(layout, refresh_per_second=10, screen=True) as live:
                while self.running:
                    layout["menu"].update(self.generate_menu())
                    layout["main"].update(self.generate_logs())

                    if os.name == 'nt':
                        if msvcrt.kbhit():
                            key = msvcrt.getch().lower()
                            if key == b'k': 
                                self.selected_index = (self.selected_index - 1) % len(self.service_names)
                            elif key == b'j':
                                self.selected_index = (self.selected_index + 1) % len(self.service_names)
                            elif key == b'q' or key == b'\x03': 
                                self.running = False
                    else:
                        if select.select([_sys.stdin], [], [], 0)[0]:
                            key = _sys.stdin.read(1).lower()
                            if key == 'k': 
                                self.selected_index = (self.selected_index - 1) % len(self.service_names)
                            elif key == 'j':
                                self.selected_index = (self.selected_index + 1) % len(self.service_names)
                            elif key == 'q' or key == '\x03': 
                                self.running = False
                    
                    time.sleep(0.05)
        finally:
            # Restore terminal settings on Linux
            if old_settings is not None:
                termios.tcsetattr(_sys.stdin, termios.TCSADRAIN, old_settings)
            self.stop_all_services()

def launch_hub(include_mobile=False):
    # Full system sweep before starting anything
    sweep_zombies()
    api_port = int(os.getenv("API_PORT", "8000"))
    free_port(api_port)
    
    if include_mobile:
        emulator_id = "Medium_Phone_API_36.1"
        print(f"[SCREEN] Launching emulator: {emulator_id}")
        try:
            subprocess.Popen(
                ["flutter", "emulators", "--launch", emulator_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                shell=True
            )
            # Wait for boot
            print("[WAIT] Waiting 15s for emulator to boot...")
            time.sleep(15)
        except Exception:
            print("[WARN] Emulator launch failed. Proceeding with Hub only.")

    try:
        hub = LogHub(include_mobile=include_mobile)
        hub.run()
    except Exception as e:
        print(f"FAILED TO START SYSTEM: {e}")

def main_mobile():
    """CLI Entry Point for the mobile launcher."""
    launch_hub(include_mobile=True)

if __name__ == "__main__":
    # Check for --mobile flag
    has_mobile = "--mobile" in sys.argv
    launch_hub(include_mobile=has_mobile)