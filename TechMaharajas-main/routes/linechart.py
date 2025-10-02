from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request, jsonify
from psycopg2.extras import RealDictCursor
import psycopg2
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

linechart_bp = Blueprint("linechart_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

def parse_input_date(date_str: str) -> datetime:
    fmts = ["%d/%m/%y", "%d-%m-%y", "%Y-%m-%d"]
    for f in fmts:
        try:
            dt = datetime.strptime(date_str.strip(), f)
            return dt.replace(tzinfo=timezone.utc)
        except Exception:
            pass
    raise ValueError("unsupported date format")

def week_window(dt_utc_midnight: datetime) -> tuple[datetime, datetime]:
    delta_days = dt_utc_midnight.weekday()
    week_start = (dt_utc_midnight - timedelta(days=delta_days)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    week_end = week_start + timedelta(days=7)
    return week_start, week_end

@linechart_bp.get("/linechart")
def linechart():
    raw_date = request.args.get("date", type=str)
    shop_id = request.args.get("shop_id", type=int)
    if not raw_date or shop_id is None:
        return jsonify({"error": "date (DD/MM/YY or YYYY-MM-DD) and shop_id (int) are required"}), 400

    try:
        day = parse_input_date(raw_date)
    except Exception:
        return jsonify({"error": "unsupported date format. Try 12/9/25 or 2025-09-12"}), 400

    wk_start, wk_end = week_window(day)

    sql = """
        WITH params AS (
            SELECT %(wk_start)s::timestamptz AS wk_start,
                   %(wk_end)s::timestamptz   AS wk_end,
                   %(shop_id)s::int          AS shop_id
        ),
        overlapping AS (
            SELECT s.id AS shift_id,
                   st.id AS staff_id,
                   s.shift_start,
                   s.shift_end
            FROM shifts s
            JOIN staff st ON st.id = s.staff_id
            CROSS JOIN params p
            WHERE st.shop_id = p.shop_id
              AND s.shift_end   > p.wk_start
              AND s.shift_start < p.wk_end
        ),
        clipped AS (
            SELECT staff_id,
                   GREATEST(shift_start, p.wk_start) AS clip_start,
                   LEAST(shift_end,   p.wk_end)   AS clip_end
            FROM overlapping
            CROSS JOIN params p
            WHERE LEAST(shift_end, p.wk_end) > GREATEST(shift_start, p.wk_start)
        ),
        per_day AS (
            SELECT date_trunc('day', clip_start) AS day_start,
                   staff_id,
                   clip_start, clip_end
            FROM clipped
        ),
        day_clipped AS (
            SELECT staff_id,
                   day_start,
                   GREATEST(clip_start, day_start) AS ds,
                   LEAST(clip_end, day_start + interval '1 day') AS de
            FROM per_day
        ),
        valid AS (
            SELECT staff_id, day_start, ds, de
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

    params = {"wk_start": wk_start, "wk_end": wk_end, "shop_id": shop_id}

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    day_list = [(wk_start + timedelta(days=i)).date().isoformat() for i in range(7)]
    by_day = {r["day"]: r for r in rows}
    data = [{"day": d, "employees_worked": by_day.get(d, {}).get("employees_worked", 0),
             "total_hours": by_day.get(d, {}).get("total_hours", 0.0)} for d in day_list]

    return jsonify({
        "shop_id": shop_id,
        "window_start": wk_start.date().isoformat(),
        "window_end_exclusive": wk_end.date().isoformat(),
        "data": data
    })
