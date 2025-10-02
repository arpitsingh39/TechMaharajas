from __future__ import annotations
import os, re
from typing import Dict, List

from flask import Blueprint, request, jsonify
from dotenv import load_dotenv
import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Json

load_dotenv()
DBURL = os.getenv("DBURL")
if not DBURL:
    raise RuntimeError("DBURL missing in env")

availability_bp = Blueprint("availability_bp", __name__, url_prefix="/api")

# Expected weekly keys
WEEKDAYS = ("monday","tuesday","wednesday","thursday","friday","saturday","sunday")

# HH:MM 24h
TIME_RE = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")

def _conn():
    return psycopg.connect(DBURL)  # psycopg3 connection [web:505]

def _parse_range(r: str):
    if not isinstance(r, str) or "-" not in r:
        return None, None
    start, end = r.split("-", 1)
    start = start.strip()
    end = end.strip()
    if not TIME_RE.match(start) or not TIME_RE.match(end):
        return None, None
    return start, end

def _to_minutes(t: str) -> int:
    h, m = t.split(":")
    return int(h) * 60 + int(m)

def _validate_day_ranges(ranges: List[str]) -> tuple[bool, str]:
    """Validate a day's ranges: 'HH:MM-HH:MM', start<end, non-overlapping."""
    mins: List[tuple[int,int,str]] = []
    for r in ranges:
        s, e = _parse_range(r)
        if s is None:
            return False, f"Invalid time range format: {r}"
        sm, em = _to_minutes(s), _to_minutes(e)
        if sm >= em:
            return False, f"Start must be earlier than end in range: {r}"
        mins.append((sm, em, r))
    mins.sort(key=lambda x: x[0])
    for i in range(1, len(mins)):
        if mins[i][0] < mins[i-1][1]:
            return False, f"Overlapping ranges: {mins[i-1][2]} overlaps {mins[i][2]}"
    return True, ""

def _normalize_week(week: Dict[str, List[str]]) -> Dict[str, List[str]]:
    """Lowercase weekday keys, ensure all weekdays exist (missing -> empty list), and strip whitespace."""
    out: Dict[str, List[str]] = {d: [] for d in WEEKDAYS}
    for k, v in (week or {}).items():
        if not isinstance(k, str):
            continue
        key = k.strip().lower()
        if key in out and isinstance(v, list):
            cleaned = [str(x).strip() for x in v if isinstance(x, str)]
            out[key] = cleaned
    return out

@availability_bp.post("/availability/save")
def availability_save():
    """
    Save full-week availability JSON into staff.availability for a staff member.

    Body JSON:
    {
      "shop_id": 1,
      "staff_id": 10,
      "availability": {
        "monday": ["09:00-10:00", "20:00-21:00"],
        ...
      },
      "mode": "replace" | "merge"   # optional, default "replace"
    }
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    p = request.get_json(silent=True) or {}
    shop_id = p.get("shop_id")
    staff_id = p.get("staff_id")
    avail = p.get("availability")
    mode = (p.get("mode") or "replace").lower()

    if not isinstance(shop_id, int) or not isinstance(staff_id, int):
        return jsonify({"error": "shop_id and staff_id must be integers"}), 400
    if not isinstance(avail, dict):
        return jsonify({"error": "availability must be an object { weekday: [\"HH:MM-HH:MM\", ...], ... }"}), 400
    if mode not in ("replace", "merge"):
        return jsonify({"error": "mode must be 'replace' or 'merge'"}), 400

    week = _normalize_week(avail)

    # Validate all days
    for day in WEEKDAYS:
        day_ranges = week.get(day, [])
        if not isinstance(day_ranges, list):
            return jsonify({"error": f"{day} must be a list of ranges"}), 400
        ok, msg = _validate_day_ranges(day_ranges)
        if not ok:
            return jsonify({"error": f"{day}: {msg}"}), 400

    sql_check = "SELECT id, availability FROM staff WHERE id = %s AND shop_id = %s FOR UPDATE"
    sql_update = "UPDATE staff SET availability = %s WHERE id = %s AND shop_id = %s RETURNING id"

    with _conn() as conn, conn.cursor(row_factory=dict_row) as cur:
        # Lock row to avoid concurrent modification/delete
        cur.execute(sql_check, (staff_id, shop_id))
        row = cur.fetchone()
        if not row:
            conn.rollback()
            return jsonify({"error": "staff_not_found"}), 404

        current_week = row.get("availability") or {}
        if mode == "merge" and isinstance(current_week, dict):
            to_store = dict(current_week)
            # merge incoming days over current
            for d in WEEKDAYS:
                if d in week:
                    to_store[d] = week[d]
        else:
            to_store = week

        # Write JSONB using psycopg Json adapter
        cur.execute(sql_update, (Json(to_store), staff_id, shop_id))
        updated = cur.fetchone()
        if not updated:
            # UPDATE cannot delete; fail fast if no row returned
            conn.rollback()
            return jsonify({"error": "update_failed"}), 409

        # Re-verify existence before commit (defensive)
        cur.execute("SELECT 1 FROM staff WHERE id = %s AND shop_id = %s", (staff_id, shop_id))
        still_there = cur.fetchone()
        if not still_there:
            conn.rollback()
            return jsonify({"error": "row_missing_after_update"}), 500

        conn.commit()

    non_empty_days = [d for d in WEEKDAYS if week.get(d)]
    return jsonify({
        "message": "availability_saved",
        "shop_id": shop_id,
        "staff_id": staff_id,
        "mode": mode,
        "days_with_entries": non_empty_days
    }), 200
