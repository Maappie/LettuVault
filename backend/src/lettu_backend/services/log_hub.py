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
LOG_LIMIT = 50 
SERVICES = {
    "BROKER": {
        "cmd": [sys.executable, "-m", "lettu_backend.services.broker_service"],
        "color": "yellow",
        "logs": deque(maxlen=LOG_LIMIT)
    },
    "BACKEND": {
        "cmd": [sys.executable, "-m", "uvicorn", "lettu_backend.main:app", "--host", "0.0.0.0", "--port", "8000"],
        "color": "green",
        "logs": deque(maxlen=LOG_LIMIT)
    },
    "MQTT": {
        "cmd": [sys.executable, "-m", "lettu_backend.services.mqtt_service"],
        "color": "cyan",
        "logs": deque(maxlen=LOG_LIMIT)
    },
    "AI": {
        "cmd": [sys.executable, "-m", "lettu_vault_ai.predict"],
        "color": "magenta",
        "logs": deque(maxlen=LOG_LIMIT)
    }
}

class LogHub:
    def __init__(self):
        self.selected_index = 0
        self.service_names = list(SERVICES.keys())
        self.running = True
        self.console = Console()
        os.makedirs("data", exist_ok=True)

    def capture_logs(self, name):
        service = SERVICES[name]
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONPATH"] = os.path.abspath(os.curdir) + ";" + env.get("PYTHONPATH", "")

        try:
            proc = subprocess.Popen(
                service["cmd"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                bufsize=1,
                encoding='utf-8',
                errors='replace',
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
            )
            
            for line in iter(proc.stdout.readline, ""):
                if not self.running: break
                clean_line = "".join(ch for ch in line if ch.isprintable() or ch in "\n\r\t")
                stripped = clean_line.strip()
                # Filter noisy amqtt deprecation warnings from broker tab
                if stripped and not any(x in stripped for x in [
                    "DeprecationWarning", "warn(", "Use `plugin`", "instead.", "section of config"
                ]):
                    service["logs"].append(stripped)
            
            if proc.poll() is None:
                proc.terminate()
            else:
                if proc.returncode != 0:
                    service["logs"].append(f"ERROR: {name} exited (code {proc.returncode})")
        except Exception as e:
            service["logs"].append(f"ERROR: {str(e)}")

    def make_layout(self):
        layout = Layout()
        layout.split_row(
            Layout(name="menu", size=18),
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
        service = SERVICES[name]
        log_text = Text()
        
        for log in list(service["logs"]):
            log_text.append(f"{log}\n", style=service["color"])
        
        return Panel(
            log_text, 
            title=f"STREAM: {name}", 
            subtitle="Switch: j/k | Quit: q",
            border_style=service["color"]
        )

    def run(self):
        # BROKER starts first, rest start after a delay
        broker_thread = threading.Thread(target=self.capture_logs, args=("BROKER",), daemon=True)
        broker_thread.start()
        
        # Give broker 4 seconds to fully start before anything tries to connect
        time.sleep(4)
        
        for name in ["BACKEND", "MQTT", "AI"]:
            threading.Thread(target=self.capture_logs, args=(name,), daemon=True).start()
            time.sleep(0.5)  # Small gap between each service

        layout = self.make_layout()
        
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

def launch_hub():
    try:
        hub = LogHub()
        hub.run()
    except Exception as e:
        print(f"FAILED TO START: {e}")
    finally:
        print("\nStopping LettuVault...")

if __name__ == "__main__":
    launch_hub()
