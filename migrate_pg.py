import psycopg2
import sys

# DATABASE_URL = "postgresql+psycopg2://capstone:capstonedesign@siondk.home.kg:5432/capstone_design_db"
# psycopg2 expects "dbname=capstone_design_db user=capstone password=capstonedesign host=siondk.home.kg port=5432"

try:
    conn = psycopg2.connect(
        dbname="capstone_design_db",
        user="capstone",
        password="capstonedesign",
        host="siondk.home.kg",
        port="5432"
    )
    cur = conn.cursor()
    # Check if column exists
    cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='post' AND column_name='is_notice';")
    exists = cur.fetchone()
    
    if not exists:
        cur.execute("ALTER TABLE post ADD COLUMN is_notice BOOLEAN DEFAULT FALSE;")
        conn.commit()
        print("Successfully added is_notice to post table")
    else:
        print("is_notice column already exists")
    
    cur.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
