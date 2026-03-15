import sqlite3
import os

db_path = "data/lettu_vault.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check AI Scans
    cursor.execute("SELECT COUNT(*) FROM ai_scans")
    ai_count = cursor.fetchone()[0]
    
    # Check Sensor Readings
    cursor.execute("SELECT COUNT(*) FROM sensor_readings")
    sensor_count = cursor.fetchone()[0]
    
    print(f"📊 Database Status Check:")
    print(f"✅ AI Detection Records: {ai_count}")
    print(f"✅ Sensor Reading Records: {sensor_count}")
    
    if ai_count > 0:
        print("\nLatest AI Detection:")
        cursor.execute("SELECT timestamp, label FROM ai_scans ORDER BY id DESC LIMIT 1")
        print(cursor.fetchone())
        
    conn.close()
else:
    print(f"Database not found at {db_path}")
