from __future__ import annotations

import os
import sys
import psycopg2
from dotenv import load_dotenv

# Load DBURL from .env
load_dotenv()
DBURL = os.getenv("DBURL")
if not DBURL:
    print("ERROR: DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)", file=sys.stderr)
    sys.exit(1)

SQL_CHECK = """
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staff'
  AND column_name = 'max_hours_per_day';
"""

SQL_ALREADY_RENAMED = """
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staff'
  AND column_name = 'max_hours_per_week';
"""

SQL_RENAME = """
ALTER TABLE public.staff
RENAME COLUMN max_hours_per_day TO max_hours_per_week;
"""

def main():
    try:
        with psycopg2.connect(DBURL) as conn, conn.cursor() as cur:
            # If already renamed, do nothing
            cur.execute(SQL_ALREADY_RENAMED)
            if cur.fetchone():
                print("Column already named max_hours_per_week; no changes made.")
                return

            # Ensure old column exists before renaming
            cur.execute(SQL_CHECK)
            if not cur.fetchone():
                print("ERROR: Column max_hours_per_day not found on public.staff.", file=sys.stderr)
                sys.exit(2)

            # Rename
            cur.execute(SQL_RENAME)
            conn.commit()
            print("Renamed staff.max_hours_per_day -> staff.max_hours_per_week")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(3)

if __name__ == "__main__":
    main()
