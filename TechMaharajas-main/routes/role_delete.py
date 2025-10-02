from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

role_delete_bp = Blueprint("role_delete_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env")
    return psycopg2.connect(DBURL)

@role_delete_bp.delete("/role/delete")
def role_delete():
    role_id = request.args.get("role_id", type=int)
    shop_id = request.args.get("shop_id", type=int)
    if role_id is None or shop_id is None:
        return jsonify({"error": "role_id and shop_id are required as ints"}), 400

    sql = "DELETE FROM roles WHERE id = %s AND shop_id = %s"
    try:
        with _get_conn() as conn, conn.cursor() as cur:
            cur.execute(sql, (role_id, shop_id))
            deleted = cur.rowcount
            conn.commit()
    except psycopg2.errors.ForeignKeyViolation as e:
        return jsonify({"error": "foreign_key_violation", "details": str(e)}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if deleted == 0:
        return jsonify({"message": "no_role_deleted"}), 404
    return jsonify({"message": "role_deleted", "deleted": deleted})
