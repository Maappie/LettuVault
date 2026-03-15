import sqlite3
import os

db_path = "data/lettu_vault.db"
if os.path.exists(db_path):
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        print("🧹 Clearing AI Scans...")
        cursor.execute("DELETE FROM ai_scans")
        
        print("🧹 Clearing Sensor Readings...")
        cursor.execute("DELETE FROM sensor_readings")
        
        conn.commit()
        conn.close()
        print("✅ Database cleared successfully!")
    except Exception as e:
        print(f"❌ Error: {e}")
else:
    print(f"Database not found at {db_path}")
