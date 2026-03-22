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
import msvcrt 

# Configuration
LOG_LIMIT = 100 

def sweep_zombies():
    """Aggressively kills any existing LettuVault processes before starting, excluding current PID."""
    if os.name == 'nt':
        my_pid = os.getpid()
        keywords = ["lettu_backend", "lettu_vault_ai", "uvicorn", "broker_service"]
        print(f"🔍 Sweeping for zombie processes (Excluding my PID: {my_pid})...")
        try:
            # We use PowerShell for a more surgical strike that can exclude our own PID
            for kw in keywords:
                ps_cmd = f"Get-Process | Where-Object {{ ($_.CommandLine -like '*{kw}*') -and ($_.Id -ne {my_pid}) }} | Stop-Process -Force"
                subprocess.run(["powershell", "-Command", ps_cmd], capture_output=True)
            time.sleep(1) # Wait for OS to cleanup
        except:
            pass
    print("✅ System swept. Starting fresh.")

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
            "cmd": [sys.executable, "-m", "lettu_backend.services.broker_service"],
            "color": "yellow",
            "desc": "Central MQTT Hub"
        },
        "API SERVER": {
            "cmd": [sys.executable, "-m", "uvicorn", "lettu_backend.main:app", "--host", "0.0.0.0", "--port", "8000"],
            "color": "green",
            "desc": "Main Backend & Web"
        },
        "SUBSCRIBERS": {
            "cmd": [sys.executable, "-m", "lettu_backend.services.mqtt"],
            "color": "cyan",
            "desc": "DB Storage"
        },
        "PUBLISHERS": {
            "cmd": [sys.executable, "-m", "lettu_vault_ai.predict"],
            "color": "magenta",
            "desc": "AI Detector"
        }
    }

    def __init__(self):
        self.selected_index = 0
        self.service_names = list(self.SERVICES.keys())
        self.running = True
        self.console = Console()
        self.logs = {name: deque(maxlen=LOG_LIMIT) for name in self.service_names}
        self.processes = {} 
        os.makedirs("data", exist_ok=True)
        
        # Register the cleanup function to run even if the terminal window is closed abruptly
        atexit.register(self.stop_all_services)

    def capture_logs(self, name):
        service_cfg = self.SERVICES.get(name)
        if not service_cfg:
            return

        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONPATH"] = os.path.abspath(os.curdir) + ";" + env.get("PYTHONPATH", "")

        while self.running:
            try:
                self.logs[name].append(f"🔄 [SYSTEM] Starting {name}...")
                proc = subprocess.Popen(
                    service_cfg["cmd"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    env=env,
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
                
                if not self.running:
                    break
                
                exit_code = proc.poll()
                self.logs[name].append(f"⚠️ [SYSTEM] {name} stopped (Code: {exit_code}). Restarting in 3s...")
                time.sleep(3) 
                
            except Exception as e:
                if not self.running: break
                self.logs[name].append(f"❌ [SYSTEM] Error in {name}: {str(e)}. Retrying in 5s...")
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
        
        for name in ["API SERVER", "SUBSCRIBERS", "PUBLISHERS"]:
            threading.Thread(target=self.capture_logs, args=(name,), daemon=True).start()
            time.sleep(0.3)

        layout = self.make_layout()
        try:
            with Live(layout, refresh_per_second=10, screen=True) as live:
                while self.running:
                    layout["menu"].update(self.generate_menu())
                    layout["main"].update(self.generate_logs())

                    if msvcrt.kbhit():
                        key = msvcrt.getch().lower()
                        if key == b'k': 
                            self.selected_index = (self.selected_index - 1) % len(self.service_names)
                        elif key == b'j':
                            self.selected_index = (self.selected_index + 1) % len(self.service_names)
                        elif key == b'q' or key == b'\x03': 
                            self.running = False
                    
                    time.sleep(0.05)
        finally:
            self.stop_all_services()

def launch_hub():
    # Full system sweep before starting anything
    sweep_zombies()
    free_port(8000)
    
    try:
        hub = LogHub()
        hub.run()
    except Exception as e:
        print(f"FAILED TO START SYSTEM: {e}")

if __name__ == "__main__":
    launch_hub()