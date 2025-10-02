from __future__ import annotations

def validate_json(data, fields):
    return all(field in data and str(data[field]).strip() for field in fields)


import os
from flask import Blueprint, request, jsonify
import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()
DBURL = os.getenv("DBURL") or os.getenv("DATABASE_URL")

login_bp = Blueprint("login_bp", __name__, url_prefix="/api")


def _get_conn():
    if not DBURL:
        raise RuntimeError("DBURL not set in .env (DBURL=postgresql://user:pass@host:port/dbname)")
    return psycopg.connect(DBURL)


def _has_column(cur, table: str, column: str) -> bool:
    cur.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_name = %s AND column_name = %s LIMIT 1",
        (table, column),
    )
    return cur.fetchone() is not None


# ---------------------- ROUTES ----------------------


# Check if shop exists (by name)
@login_bp.post('/check-shop')
def check_shop():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    data = request.get_json(silent=True) or {}
    shop_name = data.get("shop_name")
    if not shop_name or not str(shop_name).strip():
        return jsonify({'error': 'shop_name is required'}), 400

    try:
        with _get_conn() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute("SELECT id FROM shops WHERE name = %s LIMIT 1", (shop_name.strip(),))
            row = cur.fetchone()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({'exists': bool(row)}), 200


# Signup (Create Shop Profile)
@login_bp.post('/signup')
def signup():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    data = request.get_json(silent=True) or {}

    required_fields = ['shop_name', 'password', 'start_time', 'end_time']
    missing = [f for f in required_fields if not str(data.get(f, '')).strip()]
    if missing:
        return jsonify({'error': 'validation_failed', 'details': missing}), 400

    shop_name = data['shop_name'].strip()
    password = data['password']
    start_time = data['start_time']
    end_time = data['end_time']

    hashed = generate_password_hash(password)

    try:
        with _get_conn() as conn, conn.cursor(row_factory=dict_row) as cur:
            # Ensure unique shop name
            cur.execute("SELECT id FROM shops WHERE name = %s LIMIT 1", (shop_name,))
            if cur.fetchone():
                return jsonify({'error': 'shop_name_exists'}), 400

            # Insert shop (note: existing schema uses columns: name, open_time, close_time, open_days)
            cur.execute(
                "INSERT INTO shops (name, open_time, close_time) VALUES (%s, %s, %s) RETURNING id, name, open_time, close_time",
                (shop_name, start_time, end_time),
            )
            shop = cur.fetchone()

            # If shops table already has a password or password_hash column, update it; otherwise leave a hint
            password_column = None
            if _has_column(cur, 'shops', 'password'):
                password_column = 'password'
            elif _has_column(cur, 'shops', 'password_hash'):
                password_column = 'password_hash'

            if password_column:
                cur.execute(f"UPDATE shops SET {password_column} = %s WHERE id = %s", (hashed, shop['id']))
            else:
                # No password column to write into; keep DB schema untouched and inform caller
                conn.commit()
                return (
                    jsonify({
                        'message': 'shop_created_without_password_column',
                        'shop': {'id': shop['id'], 'name': shop['name'], 'open_time': shop['open_time'], 'close_time': shop['close_time']},
                        'note': "DB schema does not have a 'password' or 'password_hash' column on 'shops'. To enable login, add a text column and update the row. Example SQL: ALTER TABLE shops ADD COLUMN password_hash text; UPDATE shops SET password_hash = '<hash>' WHERE id = <id>"
                    }),
                    201,
                )

            conn.commit()
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    return (
        jsonify({
            'message': 'shop_created',
            'shop': {'id': shop['id'], 'name': shop['name'], 'open_time': shop['open_time'], 'close_time': shop['close_time']}
        }),
        201,
    )


# Login
@login_bp.post('/login')
def login():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    data = request.get_json(silent=True) or {}
    if not validate_json(data, ['shop_name', 'password']):
        return jsonify({'error': 'validation_failed', 'details': ['shop_name', 'password']}), 400

    shop_name = data['shop_name'].strip()
    password = data['password']

    try:
        with _get_conn() as conn, conn.cursor(row_factory=dict_row) as cur:
            # Try to select common password columns if present
            cols = 'id, name, open_time, close_time'
            # add optional cols if they exist
            if _has_column(cur, 'shops', 'password'):
                cols += ", password"
            if _has_column(cur, 'shops', 'password_hash'):
                cols += ", password_hash"

            cur.execute(f"SELECT {cols} FROM shops WHERE name = %s LIMIT 1", (shop_name,))
            shop = cur.fetchone()

            if not shop:
                return jsonify({'error': 'invalid_credentials'}), 401

            pw = None
            if 'password' in shop and shop['password']:
                pw = shop['password']
            elif 'password_hash' in shop and shop['password_hash']:
                pw = shop['password_hash']

            if not pw:
                return (
                    jsonify({'error': 'login_not_configured', 'note': "Password storage not configured on shops table"}),
                    400,
                )

            if not check_password_hash(pw, password):
                return jsonify({'error': 'invalid_credentials'}), 401

            return (
                jsonify({
                    'status': 'success',
                    'shop': {'id': shop['id'], 'name': shop['name'], 'open_time': shop['open_time'], 'close_time': shop['close_time']}
                }),
                200,
            )

    except Exception as e:
        return jsonify({'error': str(e)}), 500



    except Exception as e:
        return jsonify({'error': str(e)}), 500
