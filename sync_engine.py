# sync_engine.py
# ─────────────────────────────────────────────────────────────────────────────
# LettuVault Edge → Cloud Sync Engine
#
# Runs as a background process on the Raspberry Pi alongside the main app.
# Periodically queries the LOCAL SQLite database for new records and ships
# them in batches to the Cloud Server's /sync endpoint.
#
# Features:
#   ✅  Offline-safe: gracefully waits for connectivity before retrying
#   ✅  No data loss: tracks last-synced timestamp in a local state file
#   ✅  Batched uploads to minimize HTTP overhead
#   ✅  Appends VAULT_ID from .env to every record
# ─────────────────────────────────────────────────────────────────────────────

import base64
import json
import logging
import os
import socket
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
import sqlite3
from dotenv import load_dotenv, find_dotenv

# ── Config ────────────────────────────────────────────────────────────────────
load_dotenv(find_dotenv())

VAULT_ID            = os.getenv("VAULT_ID", "VAULT_UNKNOWN")
CLOUD_SYNC_API_KEY  = os.getenv("CLOUD_SYNC_API_KEY", "")
CLOUD_SYNC_URL      = os.getenv("CLOUD_SYNC_URL", "")         # e.g. https://lettuvault-cloud.onrender.com/api/v1/sync
LOCAL_DB_PATH       = os.getenv("LOCAL_DB_PATH", "data/lettu_vault.db")
VAULT_USER_EMAIL    = os.getenv("VAULT_USER_EMAIL", "")        # Set after cloud auth during onboarding

SYNC_INTERVAL_SECS  = int(os.getenv("SYNC_INTERVAL_SECS", "60"))   # How often to sync (default: 1 min)
BATCH_SIZE          = int(os.getenv("SYNC_BATCH_SIZE", "100"))       # Max records per sync call
STATE_FILE          = Path(__file__).parent / "data" / "sync_state.json"

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [SYNC] %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("SyncEngine")


# ─────────────────────────────────────────────────────────────────────────────
# STATE MANAGEMENT
# Persists the last successfully synced timestamp for each table so we never
# re-send data after a restart and never miss new rows after a network gap.
# ─────────────────────────────────────────────────────────────────────────────

DEFAULT_STATE = {
    "last_synced_sensor":    "1970-01-01T00:00:00",
    "last_synced_condition":  "1970-01-01T00:00:00",
    "last_synced_produce":    "1970-01-01T00:00:00",
    "last_synced_config":     "1970-01-01T00:00:00",
}

def load_state() -> dict:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    state = DEFAULT_STATE.copy()
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, "r") as f:
                loaded = json.load(f)
                state.update(loaded)
        except (json.JSONDecodeError, IOError):
            logger.warning("⚠️  State file corrupted — resetting to defaults.")
    return state

def save_state(state: dict):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# ─────────────────────────────────────────────────────────────────────────────
# CONNECTIVITY CHECK
# ─────────────────────────────────────────────────────────────────────────────

def is_online(host: str = "8.8.8.8", port: int = 53, timeout: int = 3) -> bool:
    """Returns True if we can reach Google's DNS — lightweight internet check."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            s.connect((host, port))
        return True
    except (socket.error, OSError):
        return False


# ─────────────────────────────────────────────────────────────────────────────
# LOCAL DATABASE QUERIES
# We use raw sqlite3 here to avoid importing the full SQLAlchemy stack and to
# keep the engine fully decoupled from the FastAPI app process.
# ─────────────────────────────────────────────────────────────────────────────

def _dict_factory(cursor, row):
    """Converts sqlite3 rows to dicts."""
    return {col[0]: row[i] for i, col in enumerate(cursor.description)}

def fetch_unsynced_sensor_readings(db_path: str, since: str, limit: int) -> list[dict]:
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = _dict_factory
        cur = conn.cursor()
        cur.execute(
            "SELECT * FROM internal_environment_readings WHERE timestamp > ? ORDER BY timestamp ASC LIMIT ?",
            (since, limit),
        )
        return cur.fetchall()

def fetch_unsynced_condition_scans(db_path: str, since: str, limit: int) -> list[dict]:
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = _dict_factory
        cur = conn.cursor()
        cur.execute(
            "SELECT * FROM ai_condition_scans WHERE timestamp > ? ORDER BY timestamp ASC LIMIT ?",
            (since, limit),
        )
        return cur.fetchall()

def fetch_unsynced_produce_scans(db_path: str, since: str, limit: int) -> list[dict]:
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = _dict_factory
        cur = conn.cursor()
        cur.execute(
            "SELECT * FROM ai_produce_scans WHERE timestamp > ? ORDER BY timestamp ASC LIMIT ?",
            (since, limit),
        )
        return cur.fetchall()

def fetch_unsynced_configs(db_path: str, since: str, limit: int) -> list[dict]:
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = _dict_factory
        cur = conn.cursor()
        cur.execute(
            "SELECT * FROM system_config WHERE timestamp > ? ORDER BY timestamp ASC LIMIT ?",
            (since, limit),
        )
        return cur.fetchall()


# ─────────────────────────────────────────────────────────────────────────────
# PAYLOAD BUILDER
# Transforms raw DB rows into the SyncBatchPayload the cloud server expects.
# ─────────────────────────────────────────────────────────────────────────────

def _format_ts(raw) -> str:
    """Normalize timestamps to ISO format strings."""
    if isinstance(raw, str):
        return raw
    if isinstance(raw, datetime):
        return raw.isoformat()
    return str(raw)

def build_sensor_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":    VAULT_ID,
            "user_email":  VAULT_USER_EMAIL or None,
            "device_id":   r.get("device_id"),
            "temperature": r.get("temperature"),
            "humidity":    r.get("humidity"),
            "pressure":    r.get("pressure"),
            "timestamp":   _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def _encode_image_b64(image_path: str) -> str:
    """Read a local image file and encode it as a b64 string prefix."""
    if not image_path:
        return None
    if image_path.startswith("http"):
        return image_path
    
    root = Path(__file__).parent

    # ai_handler saves images to data/captures/<filename>
    # The DB stores just the filename (e.g. "scan_xxx.jpg")
    candidates = [
        root / "data" / "captures" / image_path,   # primary: data/captures/scan_xxx.jpg
        root / "data" / image_path,                 # fallback: data/scan_xxx.jpg
        root / image_path,                          # last resort: scan_xxx.jpg
    ]

    for full_path in candidates:
        if full_path.exists():
            try:
                with open(full_path, "rb") as f:
                    encoded = base64.b64encode(f.read()).decode("utf-8")
                    return f"b64:{encoded}"
            except Exception as e:
                logger.warning(f"⚠️ Could not encode image {full_path}: {e}")
                break

    logger.warning(f"⚠️ Image file not found for: {image_path}")
    # Return original string if processing failed or file vanished
    return image_path

def build_condition_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":         VAULT_ID,
            "user_email":       VAULT_USER_EMAIL or None,
            "worm_count":       r.get("worm_count", 0),
            "confidence_score": r.get("confidence_score"),
            "label":            r.get("label"),
            "image":            _encode_image_b64(r.get("image")),
            "timestamp":        _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def build_produce_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":         VAULT_ID,
            "user_email":       VAULT_USER_EMAIL or None,
            "produce_type":     r.get("produce_type"),
            "confidence_score": r.get("confidence_score"),
            "label":            r.get("label"),
            "image":            _encode_image_b64(r.get("image")),
            "timestamp":        _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def build_config_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":    VAULT_ID,
            "user_email":  VAULT_USER_EMAIL or None,
            "temperature": r.get("temperature"),
            "humidity":    r.get("humidity"),
            "pressure":    r.get("pressure"),
            "timestamp":   _format_ts(r["timestamp"]),
        }
        for r in rows
    ]


# ─────────────────────────────────────────────────────────────────────────────
# SYNC EXECUTION
# ─────────────────────────────────────────────────────────────────────────────

def run_sync(state: dict) -> tuple[dict, int]:
    """
    Queries the local DB, builds a batch, and POSTs it to the cloud.
    Returns (updated_state, records_sent).
    """
    sensors   = fetch_unsynced_sensor_readings(LOCAL_DB_PATH,  state["last_synced_sensor"],    BATCH_SIZE)
    conditions = fetch_unsynced_condition_scans(LOCAL_DB_PATH, state["last_synced_condition"],   BATCH_SIZE)
    produces  = fetch_unsynced_produce_scans(LOCAL_DB_PATH,    state["last_synced_produce"],     BATCH_SIZE)
    configs   = fetch_unsynced_configs(LOCAL_DB_PATH,          state["last_synced_config"],      BATCH_SIZE)

    if not sensors and not conditions and not produces and not configs:
        logger.info("✅  Nothing new to sync.")
        return state, 0

    payload = {
        "sensor_readings": build_sensor_payload(sensors),
        "condition_scans": build_condition_payload(conditions),
        "produce_scans":   build_produce_payload(produces),
        "system_configs":  build_config_payload(configs),
    }

    total = len(sensors) + len(conditions) + len(produces) + len(configs)
    
    # Clean up the base URL and append the endpoint
    base_url = CLOUD_SYNC_URL.rstrip("/")
    sync_endpoint_url = f"{base_url}/api/v1/sync"

    logger.info(f"📦  Syncing {total} record(s) to cloud ({sync_endpoint_url}) ...")

    try:
        response = requests.post(
            sync_endpoint_url,
            json=payload,
            headers={"X-SYNC-API-KEY": CLOUD_SYNC_API_KEY},
            timeout=30,  # Render free tier can take up to 30s to wake from cold start
        )
        response.raise_for_status()
        result = response.json()
        logger.info(f"☁️   Cloud accepted: {result.get('message', 'OK')}")

        # Advance the watermark timestamps so we don't re-send these rows
        new_state = state.copy()
        if sensors:
            new_state["last_synced_sensor"] = sensors[-1]["timestamp"]
        if conditions:
            new_state["last_synced_condition"] = conditions[-1]["timestamp"]
        if produces:
            new_state["last_synced_produce"] = produces[-1]["timestamp"]
        if configs:
            new_state["last_synced_config"] = configs[-1]["timestamp"]

        return new_state, total

    except requests.exceptions.ConnectionError:
        logger.warning("🔌  Network error — cloud unreachable. Will retry next cycle.")
    except requests.exceptions.Timeout:
        logger.warning("⏱️   Request timed out. Will retry next cycle.")
    except requests.exceptions.HTTPError as e:
        logger.error(f"❌  Cloud returned HTTP {e.response.status_code}: {e.response.text}")
    except Exception as e:
        logger.error(f"❌  Unexpected error during sync: {e}")

    # On any failure, return the original state unchanged — no data is lost
    return state, 0


# ── COMMAND POLLING (Top-Down execution) ──────────────────────────────────────

def poll_and_execute_commands():
    """
    Queries the Cloud for pending commands, executes them locally via localhost APIs,
    and ACKs them back to the Cloud once complete.
    """
    base_url = CLOUD_SYNC_URL.rstrip("/")
    commands_url = f"{base_url}/api/v1/sync/commands/{VAULT_ID}"
    ack_url = f"{base_url}/api/v1/sync/commands/ack"
    
    local_api_base = "http://localhost:8000/api/v1"
    
    try:
        response = requests.get(
            commands_url,
            headers={"X-SYNC-API-KEY": CLOUD_SYNC_API_KEY},
            timeout=(3, 5),  # connect=3s, read=5s — avoids 20s double-block
        )
        response.raise_for_status()
        commands = response.json()
        
        if not commands:
            return False
            
        logger.info(f"📥  Downloaded {len(commands)} pending commands from Cloud.")
        executed_any = False
        
        for cmd in commands:
            c_type = cmd.get("command_type")
            c_id = cmd.get("id")
            c_payload = cmd.get("payload_json")
            
            logger.info(f"⚡  Executing remote command: {c_type} (ID: {c_id})")
            
            try:
                # Dispatch locally — check response status before ACKing
                headers = {"X-API-KEY": os.getenv("X_API_KEY", "")}
                dispatch_ok = True
                
                if c_type == "FORCE_TEST_CAPTURE":
                    r = requests.post(f"{local_api_base}/test-camera", headers=headers, timeout=5)
                    r.raise_for_status()
                elif c_type == "TRIGGER_PRODUCE_SCAN":
                    r = requests.post(f"{local_api_base}/trigger-produce-scan", headers=headers, timeout=5)
                    r.raise_for_status()
                elif c_type == "SYSTEM_OFF":
                    r = requests.post(f"{local_api_base}/system-off", headers=headers, timeout=5)
                    r.raise_for_status()
                    logger.info(f"⏹️  SYSTEM_OFF executed — ESP32 entering standby.")
                elif c_type == "SYS_CONFIG":
                    if c_payload:
                        r = requests.post(
                            f"{local_api_base}/system_config",
                            json=json.loads(c_payload),
                            headers=headers,
                            timeout=15,  # Longer — ESP32 ACK can take a few seconds
                        )
                        if r.status_code == 503:
                            # ESP32 didn't ACK — do NOT mark as DELIVERED, retry next cycle
                            logger.warning(f"⚠️  SYS_CONFIG {c_id} rejected by local backend (503 — ESP32 not ready). Will retry.")
                            dispatch_ok = False
                        else:
                            r.raise_for_status()
                    else:
                        logger.warning(f"⚠️  SYS_CONFIG command {c_id} has no payload — skipping.")
                        dispatch_ok = False
                else:
                    logger.warning(f"⚠️  Unknown command type from cloud: {c_type}")
                
                if not dispatch_ok:
                    continue  # Leave command PENDING — will be retried next cycle
                
                # Acknowledge completion back to cloud only if local dispatch succeeded
                ack_res = requests.post(
                    ack_url,
                    json={"command_id": c_id},
                    headers={"X-SYNC-API-KEY": CLOUD_SYNC_API_KEY},
                    timeout=5
                )
                ack_res.raise_for_status()
                logger.info(f"✅  Command {c_id} ({c_type}) acknowledged.")
                executed_any = True
                
            except requests.exceptions.RequestException as e:
                logger.error(f"❌  Failed to execute/ACK local command {c_type} (ID: {c_id}): {e}")
                
        return executed_any
        
    except requests.exceptions.RequestException:
        return False # Silently fail on network error, we will retry next cycle
    except Exception as e:
        logger.error(f"❌  Unexpected error polling commands: {e}")
        return False


# ─────────────────────────────────────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────

def _keep_render_alive():
    """
    Pings the Render health endpoint every 10 minutes to prevent cold starts.
    Render free tier spins down after 15 min of inactivity — causing 30-60s delays.
    This background thread keeps it warm.
    """
    ping_url = f"{CLOUD_SYNC_URL.rstrip('/')}/cloud-server-health"
    ping_interval = 4 * 60  # 4 minutes — keeps Render warm (spins down after 15min idle)
    while True:
        try:
            time.sleep(ping_interval)
            r = requests.get(ping_url, timeout=15)
            logger.info(f"🏓  Render keep-alive ping: {r.status_code}")
        except Exception:
            pass  # Silent fail — this is best-effort only


def main():
    # ── Startup validation ────────────────────────────────────────────────────
    if not VAULT_ID or VAULT_ID == "VAULT_UNKNOWN":
        logger.error("❌  VAULT_ID is not set in .env — cannot identify this device. Exiting.")
        return
    if not CLOUD_SYNC_API_KEY:
        logger.error("❌  CLOUD_SYNC_API_KEY is not set in .env — cannot authenticate. Exiting.")
        return
    if not CLOUD_SYNC_URL:
        logger.error("❌  CLOUD_SYNC_URL is not set in .env — no destination to sync to. Exiting.")
        return

    logger.info(f"🚀  Sync Engine started | Vault: {VAULT_ID} | Interval: {SYNC_INTERVAL_SECS}s")
    logger.info(f"🗄️   Local DB : {LOCAL_DB_PATH}")
    logger.info(f"☁️   Cloud URL: {CLOUD_SYNC_URL}")

    # Start Render keep-alive thread (prevents 30-60s cold start delays)
    import threading
    _ping_thread = threading.Thread(target=_keep_render_alive, daemon=True)
    _ping_thread.start()
    logger.info("🏓  Render keep-alive thread started (pings every 10 min)")

    state = load_state()

    while True:
        try:
            if not is_online():
                logger.warning("📡  No internet connection — skipping sync cycle.")
                time.sleep(SYNC_INTERVAL_SECS)
            else:
                logger.info("🔄  Starting sync cycle...")
                state, records_sent = run_sync(state)
                save_state(state)

                logger.info("📡  Checking for remote commands...")
                commands_executed = poll_and_execute_commands()

                # ── DYNAMIC CATCH-UP LOGIC ──────────────────────────────────────
                turbo_sleep = max(1, SYNC_INTERVAL_SECS // 2)
                if records_sent >= BATCH_SIZE or commands_executed:
                    if commands_executed:
                        logger.info(f"🔥 Command executed! Next sync in {turbo_sleep}s...")
                    else:
                        logger.info(f"🔥 Backlog detected! Next batch in {turbo_sleep}s...")
                    time.sleep(turbo_sleep)
                else:
                    logger.info(f"💤  Sleeping {SYNC_INTERVAL_SECS}s until next cycle...")
                    time.sleep(SYNC_INTERVAL_SECS)

        except KeyboardInterrupt:
            logger.info("🛑  Sync Engine stopped by user.")
            break
        except Exception as e:
            # Catch-all guard — the engine must NEVER crash
            logger.error(f"❌  Unhandled exception in main loop: {e}. Continuing...")
            time.sleep(5)
if __name__ == "__main__":
    main()
