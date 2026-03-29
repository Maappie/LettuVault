import sqlite3
import os

db_path = "data/lettu_vault.db"
if os.path.exists(db_path):
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        def safe_delete(name, table):
            try:
                cursor.execute(f"DELETE FROM {table}")
                print(f"🧹 Clearing {name}...")
            except sqlite3.OperationalError as e:
                if "no such table" in str(e):
                    print(f"⚪ Skipping {name} (not created yet)")
                else:
                    print(f"❌ Error clearing {name}: {e}")

        safe_delete("AI Condition Scans", "ai_condition_scans")
        safe_delete("AI Produce Scans", "ai_produce_scans")
        safe_delete("System Config logs", "system_config")
        safe_delete("Internal Environment Readings", "internal_environment_readings")
        
        conn.commit()
        conn.close()
        print("✅ Database cleanup finished!")
    except Exception as e:
        print(f"❌ Error: {e}")
else:
    print(f"Database not found at {db_path}")
