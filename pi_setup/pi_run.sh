#!/bin/bash
# 🥬 LettuVault Standalone Server Script
# This starts the Broker, MQTT Client, AI Detection, and FastAPI Backend.

# Resolve the project root (one level up from this script)
REPO_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_PATH"

# Path to the virtual environment's python
PYTHON="$REPO_PATH/.venv/bin/python"

if [ ! -f "$PYTHON" ]; then
    echo "❌ ERROR: Virtual environment not found at $REPO_PATH/.venv"
    echo "Please run: python3 -m venv .venv && source .venv/bin/activate && pip install -e ."
    exit 1
fi

echo "--------------------------------------------------------"
echo "🥬 LETTUVAULT: STANDALONE MODE ACTIVATED"
echo "📍 Location: $REPO_PATH"
echo "--------------------------------------------------------"

# Ensure data directory exists for SQLite
mkdir -p data

# Kill any existing processes (safety sweep)
pkill -f "lettu_backend"
pkill -f "lettu_vault_ai"
pkill -f "uvicorn"
pkill -f "sync_engine"

# Set Python Path
export PYTHONPATH="$REPO_PATH/backend/src:$REPO_PATH/ai_system/src:$PYTHONPATH"

# Function to handle shutdown
cleanup() {
    echo -e "\n🛑 Shutting down LettuVault..."
    kill $PID_BROKER $PID_MQTT $PID_AI $PID_SYNC 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# 1. Start MQTT Broker (amqtt)
echo "📡 Starting MQTT Broker..."
$PYTHON -m lettu_backend.services.broker_service > data/broker.log 2>&1 &
PID_BROKER=$!
sleep 2

# 2. Start MQTT Subscribers (DB Storage)
echo "📝 Starting MQTT Subscriber client..."
$PYTHON -m lettu_backend.services.mqtt > data/mqtt.log 2>&1 &
PID_MQTT=$!

# 3. Start AI Detection (Predictor)
echo "👁️  Starting AI Detection engine..."
$PYTHON -m lettu_vault_ai.predict > data/ai_predict.log 2>&1 &
PID_AI=$!

# 4. Start Cloud Sync Engine
echo "☁️  Starting Cloud Sync Engine..."
$PYTHON sync_engine.py > data/sync_engine.log 2>&1 &
PID_SYNC=$!

# Extract API config using python-dotenv so we don't need complex bash parsing
API_HOST=$($PYTHON -c 'import os, dotenv; dotenv.load_dotenv(); print(os.getenv("API_HOST", "0.0.0.0"))')
API_PORT=$($PYTHON -c 'import os, dotenv; dotenv.load_dotenv(); print(os.getenv("API_PORT", "8000"))')

# 5. Start API Server (Main Controller) - This one stays in foreground
echo "🌐 Starting FastAPI Server on http://$API_HOST:$API_PORT..."
$PYTHON -m uvicorn lettu_backend.main:app --host "$API_HOST" --port "$API_PORT"
