# routes/piechart.py
from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Load only from .env (project root)
load_dotenv()

DBURL = os.getenv("DBURL")  # must be set in .env, e.g., DBURL="postgresql://user:pass@host:port/db"

piechart_bp = Blueprint("piechart_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (set DBURL=postgresql://user:pass@host:port/db)")
    return psycopg2.connect(DBURL)

@piechart_bp.get("/piechart")
def piechart():
    shop_id = request.args.get("shop_id", type=int)
    if shop_id is None:
        return jsonify({"error": "shop_id is required as integer query param"}), 400

    # Count staff per role for a shop. Using LEFT JOIN so roles with 0 staff appear.
    sql = """
        SELECT r.role_name,
               COALESCE(COUNT(s.id), 0)::int AS count
        FROM roles r
        LEFT JOIN staff s
          ON s.shop_id = r.shop_id
         AND s.shop_id = %s
        WHERE r.shop_id = %s
        GROUP BY r.role_name
        ORDER BY r.role_name;
    """

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (shop_id, shop_id))
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"shop_id": shop_id, "data": rows})
