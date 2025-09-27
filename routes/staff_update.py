from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

staff_update_bp = Blueprint("staff_update_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env")
    return psycopg2.connect(DBURL)

@staff_update_bp.put("/staff/update")
def staff_update():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    p = request.get_json(silent=True) or {}
    staff_id = p.get("staff_id")
    shop_id = p.get("shop_id")
    full_name = p.get("full_name")
    contact_phone = p.get("contact_phone")
    max_hours_per_week = p.get("max_hours_per_week")
    role_id = p.get("role_id")  # optional

    if not isinstance(staff_id, int) or not isinstance(shop_id, int):
        return jsonify({"error": "staff_id and shop_id must be int"}), 400

    fields = []
    vals = []
    if full_name is not None:
        if not isinstance(full_name, str) or not full_name.strip():
            return jsonify({"error": "full_name must be non-empty string"}), 400
        fields.append("name = %s")
        vals.append(full_name.strip())
    if contact_phone is not None:
        if not isinstance(contact_phone, str):
            return jsonify({"error": "contact_phone must be string"}), 400
        fields.append("contact_phone = %s")
        vals.append(contact_phone)
    if max_hours_per_week is not None:
        if not isinstance(max_hours_per_week, int):
            return jsonify({"error": "max_hours_per_week must be int"}), 400
        fields.append("max_hours_per_week = %s")
        vals.append(max_hours_per_week)

    # Optional: if staff table has role_id column, allow updating it safely
    if role_id is not None:
        if not isinstance(role_id, int):
            return jsonify({"error": "role_id must be int"}), 400
        # Ensure role belongs to same shop
        sql_check_role = "SELECT 1 FROM roles WHERE id = %s AND shop_id = %s"
        try:
            with _get_conn() as conn, conn.cursor() as cur:
                cur.execute(sql_check_role, (role_id, shop_id))
                ok = cur.fetchone()
                if not ok:
                    return jsonify({"error": "role_shop_mismatch"}), 400
        except Exception as e:
            return jsonify({"error": str(e)}), 500
        # Only append if column exists; uncomment line below if you added staff.role_id
        # fields.append("role_id = %s"); vals.append(role_id)

    if not fields:
        return jsonify({"error": "no fields to update"}), 400

    sql = f"""
        UPDATE staff
           SET {", ".join(fields)}
         WHERE id = %s AND shop_id = %s
     RETURNING id, shop_id, name, contact_phone, max_hours_per_week;
    """
    vals.extend([staff_id, shop_id])

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, vals)
            row = cur.fetchone()
            if not row:
                return jsonify({"error": "staff_not_found"}), 404
            conn.commit()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"message": "staff_updated", "staff": row})
