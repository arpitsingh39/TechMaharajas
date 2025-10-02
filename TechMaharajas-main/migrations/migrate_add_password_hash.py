from __future__ import annotations

import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg

load_dotenv()
DBURL = os.getenv("DBURL") or os.getenv("DATABASE_URL")
if not DBURL:
    raise RuntimeError("DBURL or DATABASE_URL must be set in environment or .env")

SQL_FILE = Path(__file__).with_name("001_add_password_hash.sql")

def main():
    sql = SQL_FILE.read_text(encoding="utf-8")
    print(f"Connecting to DB using DBURL from env...")
    with psycopg.connect(DBURL) as conn:
        with conn.cursor() as cur:
            print(f"Applying migration: {SQL_FILE.name}")
            cur.execute(sql)
        conn.commit()
    print("Migration applied (or already present).")

if __name__ == '__main__':
    main()
