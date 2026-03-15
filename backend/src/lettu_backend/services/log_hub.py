import sys
import os
import time
import subprocess
import threading
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

class LogHub:
    SERVICES = {
        "BROKER": {
            "cmd": [sys.executable, "-m", "lettu_backend.services.broker_service"],
            "color": "yellow",
            "desc": "Central MQTT Communication Hub"
        },
        "API SERVER": {
            "cmd": [sys.executable, "-m", "uvicorn", "lettu_backend.main:app", "--host", "0.0.0.0", "--port", "8000"],
            "color": "green",
            "desc": "Main Backend & Web Dashboard"
        },
        "SUBSCRIBERS": {
            "cmd": [sys.executable, "-m", "lettu_backend.services.mqtt_service"],
            "color": "cyan",
            "desc": "Data Listener & DB Storage"
        },
        "PUBLISHERS": {
            "cmd": [sys.executable, "-m", "lettu_vault_ai.predict"],
            "color": "magenta",
            "desc": "AI Detector & Camera Feed"
        }
    }

    def __init__(self):
        self.selected_index = 0
        self.service_names = list(self.SERVICES.keys())
        self.running = True
        self.console = Console()
        self.logs = {name: deque(maxlen=LOG_LIMIT) for name in self.service_names}
        self.processes = {} # Store process objects for clean shutdown
        os.makedirs("data", exist_ok=True)

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
                
                # If we are here, the process has exited
                if not self.running:
                    break
                
                exit_code = proc.poll()
                self.logs[name].append(f"⚠️ [SYSTEM] {name} stopped (Code: {exit_code}). Restarting in 3s...")
                time.sleep(3) # Wait before self-healing restart
                
            except Exception as e:
                if not self.running: break
                self.logs[name].append(f"❌ [SYSTEM] Error in {name}: {str(e)}. Retrying in 5s...")
                time.sleep(5)

    def stop_all_services(self):
        """Forcefully stop all running background processes."""
        self.running = False
        print("\nStopping background services...")
        for name, proc in self.processes.items():
            if proc.poll() is None:
                try:
                    # Windows specific process tree killing (more reliable)
                    if os.name == 'nt':
                        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)], 
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    else:
                        proc.terminate()
                except Exception:
                    pass
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
        
        visible_logs = list(self.logs[name])[-25:]
        for log in visible_logs:
            log_text.append(f"{log}\n", style=service_cfg["color"])
        
        return Panel(
            log_text, 
            title=f"📡 {name} ({service_cfg['desc']})", 
            subtitle="Switch: j/k | Quit: q",
            border_style=service_cfg["color"]
        )

    def run(self):
        # Start BROKER first
        threading.Thread(target=self.capture_logs, args=("BROKER",), daemon=True).start()
        time.sleep(1) # Short wait for broker
        
        # Start rest
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
    try:
        hub = LogHub()
        hub.run()
    except Exception as e:
        print(f"FAILED TO START SYSTEM: {e}")

if __name__ == "__main__":
    launch_hub()
