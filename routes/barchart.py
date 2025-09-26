# routes/barchart.py
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

barchart_bp = Blueprint("barchart_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (set DBURL=postgresql://user:pass@host:port/db)")
    return psycopg2.connect(DBURL)

def parse_date(d: str) -> datetime:
    # Expect YYYY-MM-DD; return aware UTC midnight for consistency
    dt = datetime.strptime(d, "%Y-%m-%d")
    return dt.replace(tzinfo=timezone.utc)

@barchart_bp.get("/barchart")
def barchart():
    """
    GET /api/barchart?shop_id=1&date=2025-09-26
    Returns per-employee hours worked on that date within the given shop.
    """
    shop_id = request.args.get("shop_id", type=int)
    date_str = request.args.get("date", type=str)

    if shop_id is None or not date_str:
        return jsonify({"error": "shop_id (int) and date (YYYY-MM-DD) are required"}), 400

    try:
        day_start = parse_date(date_str)           # YYYY-MM-DD 00:00:00 UTC
        day_end = day_start + timedelta(days=1)    # next day 00:00:00 UTC
    except Exception:
        return jsonify({"error": "date must be in format YYYY-MM-DD"}), 400

    # Select shifts overlapping the target day for the shop and clip to day window.
    # Use GREATEST/LEAST to clip the interval, EXTRACT(EPOCH) to get seconds, divide by 3600 for hours.
    # Join staff for names.
    sql = """
        WITH day_window AS (
            SELECT %(day_start)s::timestamptz AS day_start,
                   %(day_end)s::timestamptz   AS day_end
        ),
        overlapping AS (
            SELECT s.id AS shift_id,
                   st.id AS staff_id,
                   st.name AS staff_name,
                   GREATEST(s.shift_start, dw.day_start) AS clip_start,
                   LEAST(s.shift_end,   dw.day_end)   AS clip_end
            FROM shifts s
            JOIN staff st
              ON st.id = s.staff_id
            CROSS JOIN day_window dw
            WHERE st.shop_id = %(shop_id)s
              AND s.shift_end   > dw.day_start    -- overlaps start
              AND s.shift_start < dw.day_end      -- overlaps end
        )
        SELECT staff_id,
               staff_name,
               ROUND(SUM(EXTRACT(EPOCH FROM (clip_end - clip_start)))/3600.0, 2) AS hours
        FROM overlapping
        WHERE clip_end > clip_start
        GROUP BY staff_id, staff_name
        ORDER BY staff_name;
    """

    params = {"shop_id": shop_id, "day_start": day_start, "day_end": day_end}

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # JSON shape: { shop_id, date, data: [ { staff_id, staff_name, hours }, ... ] }
    return jsonify({
        "shop_id": shop_id,
        "date": date_str,
        "data": rows
    })
