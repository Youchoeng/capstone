import sqlite3
import os

db_path = 'backend/app.db'
if not os.path.exists(db_path):
    db_path = 'backend/project.db'
    if not os.path.exists(db_path):
        db_path = 'backend/database.db'

print(f"Using db: {db_path}")

try:
    conn = sqlite3.connect(db_path)
    # Check tables
    tables = [t[0] for t in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    print(f"Tables: {tables}")
    
    # Try adding column
    conn.execute("ALTER TABLE post ADD COLUMN is_notice BOOLEAN DEFAULT 0")
    conn.commit()
    print("Successfully added is_notice to post table")
except Exception as e:
    print(f"Error: {e}")
