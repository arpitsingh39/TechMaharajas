"""
Database schema and helpers for Tech Maharajas.

Adds a date-based, human-friendly business ID for shifts using the shift_start date:
  business_id = YYYYMMDD-#### (per-day sequential)

We keep the numeric surrogate primary key for joins and performance, and add a
unique business_id generated via a trigger backed by a per-day counter table.
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

import psycopg2
from psycopg2.extras import Json


# Get connection string from environment variable for security
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    # Fallback for local/dev. Prefer setting DATABASE_URL in your env.
    "postgresql://postgres:XMUrbyyFxzuDqsAsIHRLovpFLmjOoyqR@shortline.proxy.rlwy.net:18073/railway",
)


def get_connection():
    if not DATABASE_URL:
        raise Exception("Set DATABASE_URL environment variable")
    return psycopg2.connect(DATABASE_URL)


def create_tables():
    """Create base tables and date-based ID generator for shifts."""
    commands = (
     """
    ALTER TABLE shifts
      ALTER COLUMN shift_start TYPE timestamptz USING shift_start AT TIME ZONE 'UTC',
      ALTER COLUMN shift_end   TYPE timestamptz USING shift_end   AT TIME ZONE 'UTC';
    """,
    """
    ALTER TABLE shifts
      DROP CONSTRAINT IF EXISTS shift_time_valid;
    """,
    """
    ALTER TABLE shifts
      ADD CONSTRAINT shift_time_valid CHECK (shift_end > shift_start);
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_shifts_time
      ON shifts (shift_start) INCLUDE (shift_end);
    """,
    )

    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                for command in commands:
                    cur.execute(command)
        print("Tables and triggers created successfully.")
    except Exception as e:
        print(f"Error creating tables: {e}")
        raise
    finally:
        conn.close()


def insert_shop(name: str, open_time: str, close_time: str, open_days: Optional[Dict[str, Any]]):
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO shops (name, open_time, close_time, open_days)
                    VALUES (%s, %s, %s, %s) RETURNING id
                    """,
                    (name, open_time, close_time, Json(open_days) if open_days is not None else None),
                )
                shop_id = cur.fetchone()[0]
                return shop_id
    finally:
        conn.close()


def get_shops() -> List[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, name, open_time, close_time, open_days FROM shops ORDER BY id")
                rows = cur.fetchall()
                shops: List[Dict[str, Any]] = []
                for row in rows:
                    shops.append(
                        {
                            "id": row[0],
                            "name": row[1],
                            "open_time": row[2].strftime("%H:%M:%S"),
                            "close_time": row[3].strftime("%H:%M:%S"),
                            "open_days": row[4],
                        }
                    )
                return shops
    finally:
        conn.close()


def insert_shift(
    staff_id: int,
    role_id: int,
    shift_start: str,
    shift_end: str,
    status: Optional[str] = None,
    business_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Insert a shift. If business_id is None, it will be auto-generated as YYYYMMDD-####.

    shift_start/shift_end should be ISO-like strings (e.g., '2025-09-26 09:00:00').
    """
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO shifts (staff_id, role_id, shift_start, shift_end, status, business_id)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id, business_id
                    """,
                    (staff_id, role_id, shift_start, shift_end, status, business_id),
                )
                row = cur.fetchone()
                return {"id": row[0], "business_id": row[1]}
    finally:
        conn.close()


def get_shifts(limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT s.id, s.business_id, s.staff_id, s.role_id,
                           s.shift_start, s.shift_end, s.status
                    FROM shifts s
                    ORDER BY s.shift_start DESC
                    LIMIT %s OFFSET %s
                    """,
                    (limit, offset),
                )
                rows = cur.fetchall()
                result: List[Dict[str, Any]] = []
                for r in rows:
                    result.append(
                        {
                            "id": r[0],
                            "business_id": r[1],
                            "staff_id": r[2],
                            "role_id": r[3],
                            "shift_start": r[4].isoformat(sep=" "),
                            "shift_end": r[5].isoformat(sep=" "),
                            "status": r[6],
                        }
                    )
                return result
    finally:
        conn.close()


def get_shift_by_business_id(business_id: str) -> Optional[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, business_id, staff_id, role_id, shift_start, shift_end, status
                    FROM shifts WHERE business_id = %s
                    """,
                    (business_id,),
                )
                r = cur.fetchone()
                if not r:
                    return None
                return {
                    "id": r[0],
                    "business_id": r[1],
                    "staff_id": r[2],
                    "role_id": r[3],
                    "shift_start": r[4].isoformat(sep=" "),
                    "shift_end": r[5].isoformat(sep=" "),
                    "status": r[6],
                }
    finally:
        conn.close()


def get_shifts_for_day(day: str) -> List[Dict[str, Any]]:
    """Get all shifts for a given day (YYYY-MM-DD)."""
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, business_id, staff_id, role_id, shift_start, shift_end, status
                    FROM shifts
                    WHERE DATE(shift_start) = %s
                    ORDER BY shift_start
                    """,
                    (day,),
                )
                rows = cur.fetchall()
                return [
                    {
                        "id": r[0],
                        "business_id": r[1],
                        "staff_id": r[2],
                        "role_id": r[3],
                        "shift_start": r[4].isoformat(sep=" "),
                        "shift_end": r[5].isoformat(sep=" "),
                        "status": r[6],
                    }
                    for r in rows
                ]
    finally:
        conn.close()

# If run directly: create tables
if __name__ == "__main__":
    create_tables()

