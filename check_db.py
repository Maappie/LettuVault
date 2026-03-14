import sqlite3
import os

db_path = "data/lettu_vault.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [row[0] for row in cursor.fetchall()]
    print(f"Tables found: {tables}")
    conn.close()
else:
    print(f"Database not found at {db_path}")
