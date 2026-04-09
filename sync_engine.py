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
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            logger.warning("⚠️  State file corrupted — resetting to defaults.")
    return DEFAULT_STATE.copy()

def save_state(state: dict):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# ─────────────────────────────────────────────────────────────────────────────
# CONNECTIVITY CHECK
# ─────────────────────────────────────────────────────────────────────────────

def is_online(host: str = "8.8.8.8", port: int = 53, timeout: int = 3) -> bool:
    """Returns True if we can reach Google's DNS — lightweight internet check."""
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
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
            "device_id":   r.get("device_id"),
            "temperature": r.get("temperature"),
            "humidity":    r.get("humidity"),
            "pressure":    r.get("pressure"),
            "timestamp":   _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def build_condition_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":         VAULT_ID,
            "worm_count":       r.get("worm_count", 0),
            "confidence_score": r.get("confidence_score"),
            "label":            r.get("label"),
            "image":            r.get("image"),
            "timestamp":        _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def build_produce_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":         VAULT_ID,
            "produce_type":     r.get("produce_type"),
            "confidence_score": r.get("confidence_score"),
            "label":            r.get("label"),
            "image":            r.get("image"),
            "timestamp":        _format_ts(r["timestamp"]),
        }
        for r in rows
    ]

def build_config_payload(rows: list[dict]) -> list[dict]:
    return [
        {
            "vault_id":    VAULT_ID,
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

def run_sync(state: dict) -> dict:
    """
    Queries the local DB, builds a batch, and POSTs it to the cloud.
    Returns an updated state dict on success, or the original state on failure.
    """
    sensors   = fetch_unsynced_sensor_readings(LOCAL_DB_PATH,  state["last_synced_sensor"],    BATCH_SIZE)
    conditions = fetch_unsynced_condition_scans(LOCAL_DB_PATH, state["last_synced_condition"],   BATCH_SIZE)
    produces  = fetch_unsynced_produce_scans(LOCAL_DB_PATH,    state["last_synced_produce"],     BATCH_SIZE)
    configs   = fetch_unsynced_configs(LOCAL_DB_PATH,          state["last_synced_config"],      BATCH_SIZE)

    if not sensors and not conditions and not produces and not configs:
        logger.info("✅  Nothing new to sync.")
        return state

    payload = {
        "sensor_readings": build_sensor_payload(sensors),
        "condition_scans": build_condition_payload(conditions),
        "produce_scans":   build_produce_payload(produces),
        "system_configs":  build_config_payload(configs),
    }

    total = len(sensors) + len(conditions) + len(produces) + len(configs)
    logger.info(f"📦  Syncing {total} record(s) to cloud ({CLOUD_SYNC_URL}) ...")

    try:
        response = requests.post(
            CLOUD_SYNC_URL,
            json=payload,
            headers={"X-SYNC-API-KEY": CLOUD_SYNC_API_KEY},
            timeout=30,
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

        return new_state

    except requests.exceptions.ConnectionError:
        logger.warning("🔌  Network error — cloud unreachable. Will retry next cycle.")
    except requests.exceptions.Timeout:
        logger.warning("⏱️   Request timed out. Will retry next cycle.")
    except requests.exceptions.HTTPError as e:
        logger.error(f"❌  Cloud returned HTTP {e.response.status_code}: {e.response.text}")
    except Exception as e:
        logger.error(f"❌  Unexpected error during sync: {e}")

    # On any failure, return the original state unchanged — no data is lost
    return state


# ─────────────────────────────────────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────

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

    state = load_state()

    while True:
        try:
            if not is_online():
                logger.warning("📡  No internet connection — skipping sync cycle.")
            else:
                state = run_sync(state)
                save_state(state)

        except KeyboardInterrupt:
            logger.info("🛑  Sync Engine stopped by user.")
            break
        except Exception as e:
            # Catch-all guard — the engine must NEVER crash
            logger.error(f"❌  Unhandled exception in main loop: {e}. Continuing...")

        time.sleep(SYNC_INTERVAL_SECS)


if __name__ == "__main__":
    main()
