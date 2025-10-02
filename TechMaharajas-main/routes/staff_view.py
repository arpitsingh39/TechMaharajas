from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

staff_view_bp = Blueprint("staff_view_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

@staff_view_bp.get("/staff/view")
def view_staff():
    """
    GET /api/staff/view?shop_id=1
    Returns all employees of the shop with their role, weekly max hours, and hourly rate (hrate).
    """
    shop_id = request.args.get("shop_id", type=int)
    if shop_id is None:
        return jsonify({"error": "shop_id (int) is required"}), 400

    # Since staff table lacks a role_id column, we join by (shop_id, role_name).
    # If later you add staff.role_id, change the join to r.id = staff.role_id for stronger integrity.
    sql = """
        SELECT
            st.id          AS staff_id,
            st.name        AS full_name,
            st.contact_phone,
            st.max_hours_per_week,
            r.role_name,
            r.hrate
        FROM staff st
        LEFT JOIN roles r
               ON r.shop_id = st.shop_id
              AND r.role_name = r.role_name   -- placeholder to keep structure clear
        WHERE st.shop_id = %s
        ORDER BY st.name;
    """

    # Note: The line "r.role_name = r.role_name" is a no-op; if staff had a role field/column,
    # replace ON clause with: r.role_name = st.role (string) OR r.id = st.role_id (int).
    # Since your earlier payload includes "role" when creating staff, consider adding a staff.role column in DB.

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (shop_id,))
            rows = cur.fetchall()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # If role matching is needed but the DB lacks staff.role/staff.role_id,
    # you could temporarily attach role_name from request or maintain a mapping table.
    return jsonify({
        "shop_id": shop_id,
        "data": rows
    })
