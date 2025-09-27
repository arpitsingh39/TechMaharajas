from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

staff_delete_bp = Blueprint("staff_delete_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env")
    return psycopg2.connect(DBURL)

@staff_delete_bp.delete("/staff/delete")
def staff_delete():
    staff_id = request.args.get("staff_id", type=int)
    shop_id = request.args.get("shop_id", type=int)
    if staff_id is None or shop_id is None:
        return jsonify({"error": "staff_id and shop_id are required as ints"}), 400

    sql = "DELETE FROM staff WHERE id = %s AND shop_id = %s"
    try:
        with _get_conn() as conn, conn.cursor() as cur:
            cur.execute(sql, (staff_id, shop_id))
            deleted = cur.rowcount
            conn.commit()
    except psycopg2.errors.ForeignKeyViolation as e:
        return jsonify({"error": "foreign_key_violation", "details": str(e)}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if deleted == 0:
        return jsonify({"message": "no_staff_deleted"}), 404
    return jsonify({"message": "staff_deleted", "deleted": deleted})
