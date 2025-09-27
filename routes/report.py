from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from collections import defaultdict
from typing import Dict, Any, List

from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

report_bp = Blueprint("report_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

def parse_input_date(date_str: str | None) -> datetime:
    # Returns aware UTC midnight; if None, use today (UTC)
    if not date_str:
        return datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
    fmts = ["%d/%m/%y", "%Y-%m-%d"]
    for f in fmts:
        try:
            dt = datetime.strptime(date_str.strip(), f)
            return dt.replace(tzinfo=timezone.utc)
        except Exception:
            pass
    raise ValueError("unsupported date format. Use DD/MM/YY or YYYY-MM-DD")

def week_window(dt_utc_midnight: datetime) -> tuple[datetime, datetime]:
    # Monday 00:00 to next Monday 00:00
    delta_days = dt_utc_midnight.weekday()  # Monday=0
    start = (dt_utc_midnight - timedelta(days=delta_days)).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=7)
    return start, end

# Map weekday index to name
WD = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

@report_bp.get("/report")
def report():
    """
    GET /api/report?shop_id=1[&date=27/09/25]
    Returns a weekly payroll report (Mon..Sun) for the given shop:
      - per staff: name, hourly rate (hrate), total_hours, total_pay
      - per-day breakdown: shifts ["HH:MM-HH:MM", ...], day_hours, day_pay
      - overall week window
    """
    shop_id = request.args.get("shop_id", type=int)
    if shop_id is None:
        return jsonify({"error": "shop_id (int) is required"}), 400

    raw_date = request.args.get("date", type=str)
    try:
        anchor = parse_input_date(raw_date)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    wk_start, wk_end = week_window(anchor)

    # Pull all shifts that overlap the week for staff in the shop, along with role rate (hrate)
    # Clip to the week and to each day; aggregate per person/day; capture human-readable windows.
    sql = """
        WITH params AS (
            SELECT %(wk_start)s::timestamptz AS wk_start,
                   %(wk_end)s::timestamptz   AS wk_end,
                   %(shop_id)s::int          AS shop_id
        ),
        base AS (
            SELECT
                st.id AS staff_id,
                st.name AS staff_name,
                r.hrate AS hrate,
                s.shift_start,
                s.shift_end
            FROM shifts s
            JOIN staff st ON st.id = s.staff_id
            JOIN roles r  ON r.id = s.role_id
            CROSS JOIN params p
            WHERE st.shop_id = p.shop_id
              AND s.shift_end   > p.wk_start
              AND s.shift_start < p.wk_end
        ),
        clipped AS (
            SELECT
                staff_id, staff_name, hrate,
                GREATEST(shift_start, p.wk_start) AS clip_start,
                LEAST(shift_end,   p.wk_end)   AS clip_end
            FROM base
            CROSS JOIN params p
            WHERE LEAST(shift_end, p.wk_end) > GREATEST(shift_start, p.wk_start)
        ),
        per_day AS (
            SELECT
                staff_id, staff_name, hrate,
                date_trunc('day', clip_start) AS day_start,
                clip_start, clip_end
            FROM clipped
        ),
        day_clipped AS (
            SELECT
                staff_id, staff_name, hrate, day_start,
                GREATEST(clip_start, day_start) AS ds,
                LEAST(clip_end,   day_start + interval '1 day') AS de
            FROM per_day
        ),
        valid AS (
            SELECT staff_id, staff_name, hrate, day_start, ds, de
            FROM day_clipped
            WHERE de > ds
        )
        SELECT
            staff_id,
            staff_name,
            hrate,
            day_start,
            ds,
            de,
            EXTRACT(EPOCH FROM (de - ds))/3600.0 AS hours
        FROM valid
        ORDER BY staff_name, day_start, ds;
    """

    params = {"wk_start": wk_start, "wk_end": wk_end, "shop_id": shop_id}

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Build per-staff, per-day structure
    per_staff: Dict[int, Dict[str, Any]] = {}
    # Initialize all days for consistent output
    all_days = [(wk_start + timedelta(days=i)) for i in range(7)]
    day_keys = [d.date().isoformat() for d in all_days]

    # Default zeroed structure factory
    def new_staff(staff_id: int, staff_name: str, hrate: float) -> Dict[str, Any]:
        return {
            "staff_id": staff_id,
            "name": staff_name,
            "hrate": float(hrate) if hrate is not None else 0.0,
            "total_hours": 0.0,
            "total_pay": 0.0,
            "days": {
                dk: {
                    "weekday": WD[i],
                    "shifts": [],            # ["09:00-10:00", ...]
                    "day_hours": 0.0,
                    "day_pay": 0.0
                } for i, dk in enumerate(day_keys)
            }
        }

    # Aggregate
    for r in rows:
        sid = r["staff_id"]
        name = r["staff_name"]
        rate = r["hrate"] or 0.0
        dk = r["day_start"].date().isoformat()
        start_s = r["ds"].strftime("%H:%M")
        end_s = r["de"].strftime("%H:%M")
        hrs = float(r["hours"])

        if sid not in per_staff:
            per_staff[sid] = new_staff(sid, name, rate)

        day = per_staff[sid]["days"][dk]
        day["shifts"].append(f"{start_s}-{end_s}")
        day["day_hours"] += round(hrs, 2)
        day["day_pay"] += round(hrs * float(rate), 2)

    # Finalize totals
    for sid, rec in per_staff.items():
        total_hours = sum(rec["days"][dk]["day_hours"] for dk in day_keys)
        total_pay = sum(rec["days"][dk]["day_pay"] for dk in day_keys)
        rec["total_hours"] = round(total_hours, 2)
        rec["total_pay"] = round(total_pay, 2)

    # Return as a stable list sorted by staff name
    result = sorted(per_staff.values(), key=lambda x: x["name"].lower())

    return jsonify({
        "shop_id": shop_id,
        "window_start": wk_start.date().isoformat(),
        "window_end_exclusive": wk_end.date().isoformat(),
        "staff": result
    })
