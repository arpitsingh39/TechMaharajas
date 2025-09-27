from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import List, Tuple

from flask import Blueprint, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

schedule_bp = Blueprint("schedule_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

def parse_date_ddmmyy(d: str) -> datetime:
    # Parse DD/MM/YY into a UTC midnight datetime
    try:
        dt = datetime.strptime(d.strip(), "%d/%m/%y")
    except Exception:
        raise ValueError("date must be DD/MM/YY (e.g., 27/09/25)")
    return dt.replace(tzinfo=timezone.utc)

def parse_shift(s: str) -> Tuple[int, int, int, int]:
    # "HH:MM-HH:MM" -> (start_h, start_m, end_h, end_m)
    try:
        rng = s.strip()
        start, end = rng.split("-")
        sh, sm = [int(x) for x in start.split(":")]
        eh, em = [int(x) for x in end.split(":")]
        if not (0 <= sh < 24 and 0 <= sm < 60 and 0 <= eh < 24 and 0 <= em < 60):
            raise ValueError
        if (eh, em) <= (sh, sm):
            raise ValueError
        return sh, sm, eh, em
    except Exception:
        raise ValueError(f"invalid shift format: '{s}', expected 'HH:MM-HH:MM'")

def build_timestamps(day_utc_midnight: datetime, sh: int, sm: int, eh: int, em: int) -> Tuple[datetime, datetime]:
    start = day_utc_midnight.replace(hour=sh, minute=sm, second=0, microsecond=0)
    end = day_utc_midnight.replace(hour=eh, minute=em, second=0, microsecond=0)
    return start, end

@schedule_bp.post("/schedule")
def schedule():
    """
    POST /api/schedule
    {
      "shop_id": 1,
      "staff_id": 10,
      "role_id": 3,
      "date": "27/09/25",
      "shifts": ["09:00-10:00", "10:30-13:00", "14:00-17:00"]
    }
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415

    payload = request.get_json(silent=True) or {}
    shop_id = payload.get("shop_id")
    staff_id = payload.get("staff_id")
    role_id = payload.get("role_id")
    date_str = payload.get("date")
    shifts: List[str] = payload.get("shifts") or []

    # Basic validation
    errs = []
    if not isinstance(shop_id, int):
        errs.append("shop_id must be int")
    if not isinstance(staff_id, int):
        errs.append("staff_id must be int")
    if not isinstance(role_id, int):
        errs.append("role_id must be int")
    if not isinstance(date_str, str):
        errs.append("date must be DD/MM/YY string")
    if not isinstance(shifts, list) or not shifts:
        errs.append("shifts must be a non-empty list of 'HH:MM-HH:MM'")
    if errs:
        return jsonify({"error": "validation_failed", "details": errs}), 400

    try:
        day = parse_date_ddmmyy(date_str)
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400

    # Parse all shifts first
    parsed = []
    try:
        for s in shifts:
            sh, sm, eh, em = parse_shift(s)
            st, en = build_timestamps(day, sh, sm, eh, em)
            parsed.append({"input": s, "start": st, "end": en})
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400

    # Verify staff belongs to shop, role belongs to shop
    SQL_CHECKS = """
        SELECT EXISTS(SELECT 1 FROM staff WHERE id = %s AND shop_id = %s);
    """
    SQL_CHECK_ROLE = """
        SELECT EXISTS(SELECT 1 FROM roles WHERE id = %s AND shop_id = %s);
    """
    SQL_INSERT = """
        INSERT INTO shifts (staff_id, role_id, shift_start, shift_end, status)
        VALUES (%s, %s, %s, %s, 'scheduled')
        RETURNING id, staff_id, role_id, shift_start, shift_end, status;
    """

    results = []
    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(SQL_CHECKS, (staff_id, shop_id))
            staff_ok = cur.fetchone()["exists"]
            if not staff_ok:
                return jsonify({"error": "staff_shop_mismatch", "details": "staff does not belong to shop"}), 400

            cur.execute(SQL_CHECK_ROLE, (role_id, shop_id))
            role_ok = cur.fetchone()["exists"]
            if not role_ok:
                return jsonify({"error": "role_shop_mismatch", "details": "role does not belong to shop"}), 400

            # Insert each shift
            for item in parsed:
                cur.execute(SQL_INSERT, (staff_id, role_id, item["start"], item["end"]))
                results.append(cur.fetchone())
            conn.commit()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Build friendly echo object with times as ISO strings
    echo = [
        {
            "input": r["shift_start"].strftime("%H:%M") + "-" + r["shift_end"].strftime("%H:%M"),
            "start_iso": r["shift_start"].isoformat(),
            "end_iso": r["shift_end"].isoformat(),
            "status": r["status"]
        }
        for r in results
    ]

    return jsonify({
        "message": "ok",
        "shop_id": shop_id,
        "staff_id": staff_id,
        "role_id": role_id,
        "date": date_str,
        "saved": echo
    }), 201
