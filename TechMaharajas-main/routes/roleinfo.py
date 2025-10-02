from __future__ import annotations

import os
from flask import Blueprint, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

roleinfo_bp = Blueprint("roleinfo_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

@roleinfo_bp.get("/roleinfo")
def roleinfo():
    # Require shop_id to scope results to a single shop
    shop_id = request.args.get("shop_id", type=int)
    if shop_id is None:
        return jsonify({"error": "shop_id (int) is required"}), 400

    # hrate column is used here
    sql = """
        WITH role_counts AS (
            SELECT r.id AS role_id,
                   r.role_name,
                   r.description,
                   r.hrate AS hrate,
                   COUNT(s.id)::int AS total_workers
            FROM roles r
            LEFT JOIN staff s
              ON s.shop_id = r.shop_id
             AND s.shop_id = %s
            WHERE r.shop_id = %s
            GROUP BY r.id, r.role_name, r.description, r.hrate
        )
        SELECT role_name, hrate, total_workers, description
        FROM role_counts
        ORDER BY role_name;
    """

    sql_summary = """
        SELECT
            (SELECT COUNT(*) FROM roles WHERE shop_id = %s)::int AS total_roles,
            (SELECT COUNT(*) FROM staff WHERE shop_id = %s)::int AS total_workers;
    """

    try:
        with _get_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, (shop_id, shop_id))
                roles = cur.fetchall()
            with conn.cursor(cursor_factory=RealDictCursor) as cur2:
                cur2.execute(sql_summary, (shop_id, shop_id))
                summary = cur2.fetchone()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({
        "shop_id": shop_id,
        "summary": summary,
        "data": roles
    })
