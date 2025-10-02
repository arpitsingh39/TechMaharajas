from __future__ import annotations

import os
from datetime import datetime, timedelta, time, timezone
import random
import json

import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

# Load DBURL strictly from .env
load_dotenv()
DBURL = os.getenv("DBURL")
if not DBURL:
    raise RuntimeError("DBURL not set in .env (add DBURL=postgresql://user:pass@host:port/dbname)")

# Configuration
SHOP_NAME = "Main Store"
OPEN_TIME = time(9, 0)    # 09:00
CLOSE_TIME = time(21, 0)  # 21:00

# Choose a Monday as the start of the seeded week (change if needed)
# Use UTC-aware datetimes to match timestamptz usage
WEEK_START = datetime(2025, 9, 22, tzinfo=timezone.utc)  # Monday
DAYS = 7  # Mon..Sun
SHIFT_START_HOUR = 9
SHIFT_HOURS = 8

ROLES = [
    ("Cashier", "Handles checkout and customer payments"),
    ("Stocker", "Manages inventory and shelf restocking"),
    ("Manager", "Oversees daily operations and staff"),
    ("Security", "Ensures store safety and loss prevention"),
]

STAFF = [
    ("Alice Johnson",  "alice@example.com",  "+10000000001"),
    ("Bob Smith",      "bob@example.com",    "+10000000002"),
    ("Carol Davis",    "carol@example.com",  "+10000000003"),
    ("Dan Patel",      "dan@example.com",    "+10000000004"),
    ("Eve Williams",   "eve@example.com",    "+10000000005"),
]

# Simple availability JSON for all staff (Mon-Fri available 9-17)
AVAILABILITY = {
    "Mon": {"start": "09:00", "end": "17:00"},
    "Tue": {"start": "09:00", "end": "17:00"},
    "Wed": {"start": "09:00", "end": "17:00"},
    "Thu": {"start": "09:00", "end": "17:00"},
    "Fri": {"start": "09:00", "end": "17:00"},
    "Sat": None,
    "Sun": None
}

def main():
    with psycopg2.connect(DBURL) as conn:
        with conn.cursor() as cur:
            # 1) Insert one shop
            cur.execute(
                """
                INSERT INTO shops (name, open_time, close_time, open_days)
                VALUES (%s, %s, %s, %s)
                RETURNING id
                """,
                (SHOP_NAME, OPEN_TIME, CLOSE_TIME, json.dumps({
                    "Mon": True, "Tue": True, "Wed": True, "Thu": True, "Fri": True, "Sat": False, "Sun": False
                }))
            )
            shop_id = cur.fetchone()[0]

            # 2) Insert roles for that shop
            role_rows = [(shop_id, name, desc) for name, desc in ROLES]
            execute_values(
                cur,
                "INSERT INTO roles (shop_id, role_name, description) VALUES %s RETURNING id, role_name",
                role_rows
            )
            role_id_name = cur.fetchall()  # [(id, role_name), ...]
            # Build a consistent mapping by role_name
            role_map = {rn: rid for rid, rn in role_id_name}

            # 3) Insert 5 staff
            staff_rows = []
            for name, email, phone in STAFF:
                staff_rows.append((shop_id, name, email, phone, json.dumps(AVAILABILITY), 8))
            execute_values(
                cur,
                """
                INSERT INTO staff (shop_id, name, contact_email, contact_phone, availability, max_hours_per_day)
                VALUES %s
                RETURNING id, name
                """,
                staff_rows
            )
            staff_ids = cur.fetchall()  # [(id, name), ...]
            # Distribute staff to roles (round-robin by index)
            staff_role_assignment = {}
            role_names = [r[0] for r in ROLES]
            for idx, (sid, sname) in enumerate(staff_ids):
                staff_role_assignment[sid] = role_names[idx % len(role_names)]

            # 4) Insert one week of shifts per staff (Mon..Sun, 09:00-17:00 UTC)
            # If Sunday is not worked, still insert for test variety; adjust as needed
            shift_rows = []
            for day_offset in range(DAYS):
                d = WEEK_START + timedelta(days=day_offset)
                shift_start = d.replace(hour=SHIFT_START_HOUR, minute=0, second=0, microsecond=0)
                shift_end = shift_start + timedelta(hours=SHIFT_HOURS)
                for sid, _sname in staff_ids:
                    # All staff work daily in this seed; tweak for realism if desired
                    shift_rows.append((sid,  # staff_id
                                       role_map[staff_role_assignment[sid]],  # role_id via mapping
                                       shift_start,
                                       shift_end,
                                       "scheduled"))
            execute_values(
                cur,
                """
                INSERT INTO shifts (staff_id, role_id, shift_start, shift_end, status)
                VALUES %s
                """,
                shift_rows
            )

        conn.commit()

if __name__ == "__main__":
    main()
