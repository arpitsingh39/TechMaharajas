from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

staff_create_bp = Blueprint("staff_create_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

@staff_create_bp.post("/staff/create")
def create_staff():
    """
    Create a staff member tied to a role in the same shop.
    JSON:
    {
      "shop_id": 1,
      "full_name": "Alice Johnson",
      "role_name": "Cashier",
      "contact_phone": "+10000000001",
      "max_hours_per_week": 40
    }
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415

    data = request.get_json(silent=True) or {}
    shop_id = data.get("shop_id")
    full_name = data.get("full_name")
    role_name = data.get("role_name")
    contact_phone = data.get("contact_phone")
    max_hours_per_week = data.get("max_hours_per_week")

    errs = []
    if not isinstance(shop_id, int):
        errs.append("shop_id must be int")
    if not isinstance(full_name, str) or not full_name.strip():
        errs.append("full_name must be non-empty string")
    if not isinstance(role_name, str) or not role_name.strip():
        errs.append("role_name must be non-empty string")
    if contact_phone is not None and not isinstance(contact_phone, str):
        errs.append("contact_phone must be string or null")
    if max_hours_per_week is None or not isinstance(max_hours_per_week, int):
        errs.append("max_hours_per_week must be int")
    if errs:
        return jsonify({"error": "validation_failed", "details": errs}), 400

    # Look up the role_id for (shop_id, role_name)
    sql_get_role = """
        SELECT id, hrate
        FROM roles
        WHERE shop_id = %s AND role_name = %s
        LIMIT 1;
    """
    # Insert staff; schema columns present: shop_id, name, contact_email, contact_phone, availability, max_hours_per_week
    sql_insert_staff = """
        INSERT INTO staff (shop_id, name, contact_email, contact_phone, availability, max_hours_per_week)
        VALUES (%s, %s, NULL, %s, NULL, %s)
        RETURNING id, shop_id, name, contact_phone, max_hours_per_week;
    """

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql_get_role, (shop_id, role_name.strip()))
            role_row = cur.fetchone()
            if not role_row:
                return jsonify({"error": "role_not_found", "details": "Create role first for this shop"}), 400

            # Create staff row
            cur.execute(sql_insert_staff, (shop_id, full_name.strip(), contact_phone, max_hours_per_week))
            staff_row = cur.fetchone()
            conn.commit()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({
        "message": "staff_created",
        "staff": staff_row,
        "role": {"role_name": role_name.strip(), "hrate": role_row["hrate"]}
    }), 201
