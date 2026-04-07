"""
mobile_app_only — LettuVault Mobile Launcher
Launches ONLY the Android emulator and the Flutter app. No backend, No TUI.
"""
import subprocess
import sys
import time
import os
from lettu_backend.core.config import PROJECT_ROOT

EMULATOR_ID = "Medium_Phone_API_36.1"
FLUTTER_PROJECT_DIR = os.path.join(PROJECT_ROOT, "mobile", "LettuVault_Unfinished")
BOOT_WAIT_SECONDS = 15


def run_mobile_only():
    """Launch the Android emulator and run the Flutter app standalone."""

    print("[MOBILE] LettuVault Mobile Launcher (Standalone Mode)")
    print("=" * 50)

    # --- Step 1: Launch the emulator ---
    print(f"[1/3] Launching emulator: {EMULATOR_ID}")
    try:
        subprocess.Popen(
            ["flutter", "emulators", "--launch", EMULATOR_ID],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            shell=True
        )
    except FileNotFoundError:
        print("[ERROR] 'flutter' command not found.")
        sys.exit(1)

    # --- Step 2: Wait for boot ---
    print(f"[2/3] Waiting {BOOT_WAIT_SECONDS}s for emulator to boot...")
    for i in range(BOOT_WAIT_SECONDS, 0, -1):
        print(f"   Starting in {i}s...", end="\r", flush=True)
        time.sleep(1)
    print("   Emulator ready!                    ")

    # --- Step 3: Run Flutter app ---
    print(f"[3/3] Running Flutter app from: {FLUTTER_PROJECT_DIR}")
    print("=" * 50)

    try:
        subprocess.run(
            ["flutter", "run"],
            cwd=FLUTTER_PROJECT_DIR,
            shell=True,
            check=True
        )
    except KeyboardInterrupt:
        print("\n[MOBILE] Stopped by user.")
    except subprocess.CalledProcessError as e:
        print(f"\n[MOBILE] Flutter run failed with exit code {e.returncode}")
        sys.exit(e.returncode)
