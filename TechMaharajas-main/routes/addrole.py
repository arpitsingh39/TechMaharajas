from __future__ import annotations

import os
from flask import Blueprint, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
DBURL = os.getenv("DBURL")

addrole_bp = Blueprint("addrole_bp", __name__, url_prefix="/api")

def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg2.connect(DBURL)

@addrole_bp.post("/addrole")
def addrole():
    """
    Create a new role.
    JSON body:
    {
      "shop_id": 1,
      "role_name": "Cashier",
      "description": "Handles checkout",
      "hrate": 250.00
    }
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415

    payload = request.get_json(silent=True) or {}
    shop_id = payload.get("shop_id")
    role_name = payload.get("role_name")
    description = payload.get("description")
    hrate = payload.get("hrate")

    # Basic validation
    errors = []
    if not isinstance(shop_id, int):
        errors.append("shop_id must be int")
    if not isinstance(role_name, str) or not role_name.strip():
        errors.append("role_name must be non-empty string")
    if description is not None and not isinstance(description, str):
        errors.append("description must be string or null")
    if hrate is None or not isinstance(hrate, (int, float)):
        errors.append("hrate must be number")
    if errors:
        return jsonify({"error": "validation_failed", "details": errors}), 400

    # Optional: enforce uniqueness of role per shop (if you added such a constraint)
    # INSERT role
    sql = """
        INSERT INTO roles (shop_id, role_name, description, hrate)
        VALUES (%s, %s, %s, %s)
        RETURNING id, shop_id, role_name, description, hrate
    """

    try:
        with _get_conn() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (shop_id, role_name.strip(), description, hrate))
            created = cur.fetchone()
            conn.commit()
    except psycopg2.errors.UniqueViolation as e:
        # If a unique constraint like (shop_id, role_name) exists
        return jsonify({"error": "role_already_exists", "details": str(e)}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"message": "role_created", "role": created}), 201
