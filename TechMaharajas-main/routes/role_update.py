from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

role_update_bp = Blueprint("role_update_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env")
    return psycopg2.connect(DBURL)

@role_update_bp.put("/role/update")
def role_update():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    payload = request.get_json(silent=True) or {}
    role_id = payload.get("role_id")
    shop_id = payload.get("shop_id")
    role_name = payload.get("role_name")
    description = payload.get("description")
    hrate = payload.get("hrate")

    if not isinstance(role_id, int) or not isinstance(shop_id, int):
        return jsonify({"error": "role_id and shop_id must be int"}), 400
    fields = []
    vals = []
    if role_name is not None:
        if not isinstance(role_name, str) or not role_name.strip():
            return jsonify({"error": "role_name must be non-empty string"}), 400
        fields.append("role_name = %s")
        vals.append(role_name.strip())
    if description is not None:
        if not isinstance(description, str):
            return jsonify({"error": "description must be string"}), 400
        fields.append("description = %s")
        vals.append(description)
    if hrate is not None:
        if not isinstance(hrate, (int, float)):
            return jsonify({"error": "hrate must be number"}), 400
        fields.append("hrate = %s")
        vals.append(hrate)

    if not fields:
        return jsonify({"error": "no fields to update"}), 400

    sql = f"""
        UPDATE roles
           SET {", ".join(fields)}
         WHERE id = %s AND shop_id = %s
     RETURNING id, shop_id, role_name, description, hrate;
    """
    vals.extend([role_id, shop_id])

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, vals)
            row = cur.fetchone()
            if not row:
                return jsonify({"error": "role_not_found"}), 404
            conn.commit()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"message": "role_updated", "role": row})
