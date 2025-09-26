from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request, jsonify
from psycopg2.extras import RealDictCursor
import psycopg2
from dotenv import load_dotenv

# Load DBURL only from .env
load_dotenv()
DBURL = os.getenv("DBURL")

linechart_bp = Blueprint("linechart_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

def parse_input_date(date_str: str) -> datetime:
    """
    Accepts formats like:
      - 12/9/25  (DD/MM/YY)
      - 12-9-25
      - 2025-09-12 (YYYY-MM-DD)
    Returns an aware UTC midnight for that calendar date.
    """
    # Try DD/MM/YY and DD/M/YY with slash
    fmts = ["%d/%m/%y", "%d-%m-%y", "%Y-%m-%d"]
    last_err = None
    for f in fmts:
        try:
            dt = datetime.strptime(date_str.strip(), f)
            return dt.replace(tzinfo=timezone.utc)
        except Exception as e:
            last_err = e
    raise ValueError(str(last_err) if last_err else "Invalid date")

def week_window(dt_utc_midnight: datetime) -> tuple[datetime, datetime]:
    """
    Given a UTC midnight datetime, compute Monday 00:00:00 (inclusive)
    to next Monday 00:00:00 (exclusive) for the containing ISO week.
    """
    # weekday(): Monday=0 ... Sunday=6
    delta_days = dt_utc_midnight.weekday()  # days since Monday
    week_start = (dt_utc_midnight - timedelta(days=delta_days)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    week_end = week_start + timedelta(days=7)
    return week_start, week_end

@linechart_bp.get("/linechart")
def linechart():
    """
    GET /api/linechart?date=12/9/25
    Returns a 7-day window (Mon..Sun) containing the given date with:
      - date (YYYY-MM-DD)
      - employees_worked (distinct staff who had any overlapping shift that day)
      - total_hours (sum of hours from overlapping segments)
    """
    raw_date = request.args.get("date", type=str)
    if not raw_date:
        return jsonify({"error": "date is required, e.g., 12/9/25 or 2025-09-12"}), 400

    try:
        day = parse_input_date(raw_date)  # UTC midnight for provided date
    except Exception:
        return jsonify({"error": "unsupported date format. Try 12/9/25 (DD/MM/YY) or 2025-09-12"}), 400

    wk_start, wk_end = week_window(day)

    # Build day bins by truncating to day and clipping shift intervals to each day.
    # We count distinct staff per day and sum hours per day.
    sql = """
        WITH params AS (
            SELECT %(wk_start)s::timestamptz AS wk_start,
                   %(wk_end)s::timestamptz   AS wk_end
        ),
        -- all shifts overlapping the 7-day window with staff info
        overlapping AS (
            SELECT s.id AS shift_id,
                   st.id AS staff_id,
                   s.shift_start,
                   s.shift_end
            FROM shifts s
            JOIN staff st ON st.id = s.staff_id
            CROSS JOIN params p
            WHERE s.shift_end   > p.wk_start
              AND s.shift_start < p.wk_end
        ),
        -- clip each overlapping shift to the window first
        clipped AS (
            SELECT staff_id,
                   GREATEST(shift_start, p.wk_start) AS clip_start,
                   LEAST(shift_end,   p.wk_end)   AS clip_end
            FROM overlapping
            CROSS JOIN params p
            WHERE LEAST(shift_end, p.wk_end) > GREATEST(shift_start, p.wk_start)
        ),
        -- break clipped intervals into day buckets (start-of-day timestamps)
        per_day AS (
            SELECT date_trunc('day', clip_start) AS day_start,
                   staff_id,
                   clip_start,
                   clip_end
            FROM clipped
        ),
        -- for each row, clip again to its day boundaries to avoid crossing midnight
        day_clipped AS (
            SELECT staff_id,
                   day_start,
                   GREATEST(clip_start, day_start) AS ds,
                   LEAST(clip_end, day_start + interval '1 day') AS de
            FROM per_day
        ),
        valid AS (
            SELECT staff_id,
                   day_start,
                   ds, de
            FROM day_clipped
            WHERE de > ds
        )
        SELECT
            to_char(day_start, 'YYYY-MM-DD') AS day,
            COUNT(DISTINCT staff_id)::int     AS employees_worked,
            ROUND(SUM(EXTRACT(EPOCH FROM (de - ds)))/3600.0, 2) AS total_hours
        FROM valid
        GROUP BY day
        ORDER BY day;
    """

    params = {"wk_start": wk_start, "wk_end": wk_end}

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Ensure all 7 days present even if zero activity
    day_list = [(wk_start + timedelta(days=i)).date().isoformat() for i in range(7)]
    by_day = {r["day"]: r for r in rows}
    data = []
    for d in day_list:
        r = by_day.get(d)
        if r is None:
            data.append({"day": d, "employees_worked": 0, "total_hours": 0.0})
        else:
            data.append(r)

    return jsonify({
        "window_start": wk_start.date().isoformat(),
        "window_end_exclusive": wk_end.date().isoformat(),
        "data": data
    })
