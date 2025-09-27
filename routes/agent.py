from __future__ import annotations

import os
from typing import List, Dict, Any

from flask import Blueprint, request, jsonify
from dotenv import load_dotenv
from groq import Groq
import psycopg
from psycopg.rows import dict_row
from datetime import datetime, timezone
import requests

# ---------------- Env & clients ----------------
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
DBURL = os.getenv("DBURL")
BASE = os.getenv("BASE_URL", "https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev")

if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY missing in env")
if not DBURL:
    raise RuntimeError("DBURL missing in env")

client = Groq(api_key=GROQ_API_KEY)  # Groq chat completions client [web:506]
agent_bp = Blueprint("agent_bp", __name__, url_prefix="/api")

SYSTEM_PROMPT = (
    "You are a helpful assistant restricted to a single shop. "
    "Only answer about the provided shop_id. "
    "Do not claim that any database change was performed, as this agent is read-only. "
    "Format lists as short, clear bullet points."
)

# ---------------- Database schema & helpers ----------------
DDL_CONVERSATIONS = """
CREATE TABLE IF NOT EXISTS conversations (
  id bigserial PRIMARY KEY,
  shop_id integer NOT NULL,
  role text NOT NULL,           -- 'system' | 'user' | 'assistant'
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_conv_shop_time ON conversations (shop_id, created_at);
"""

def _conn():
    return psycopg.connect(DBURL)  # psycopg3 connection [web:505]

def _ensure_tables():
    with _conn() as conn, conn.cursor() as cur:
        cur.execute(DDL_CONVERSATIONS)

def _load_last_history(shop_id: int, limit: int = 10) -> List[Dict[str, str]]:
    with _conn() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            SELECT role, content
            FROM conversations
            WHERE shop_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (shop_id, limit),
        )
        rows = cur.fetchall()
    turns = rows[::-1]  # oldest first
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for r in turns:
        messages.append({"role": r["role"], "content": r["content"]})
    return messages

def _save_turn(shop_id: int, role: str, content: str):
    with _conn() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO conversations (shop_id, role, content, created_at) VALUES (%s, %s, %s, %s)",
            (shop_id, role, content, datetime.now(timezone.utc)),
        )
        # Keep only last 10 turns per shop
        cur.execute(
            """
            DELETE FROM conversations
            WHERE shop_id = %s
              AND id NOT IN (
                SELECT id FROM conversations
                WHERE shop_id = %s
                ORDER BY created_at DESC
                LIMIT 10
              )
            """,
            (shop_id, shop_id),
        )

# ---------------- Read-only API wrappers ----------------
def get_roleinfo(shop_id: int) -> dict:
    r = requests.get(f"{BASE}/api/roleinfo", params={"shop_id": shop_id}, timeout=30)  # GET with params [web:513]
    r.raise_for_status()
    return r.json()  # parse JSON safely [web:515]

def get_staff_view(shop_id: int) -> dict:
    r = requests.get(f"{BASE}/api/staff/view", params={"shop_id": shop_id}, timeout=30)  # GET with params [web:513]
    r.raise_for_status()
    return r.json()  # JSON body [web:515]

def get_report(shop_id: int, date: str | None = None) -> dict:
    params = {"shop_id": shop_id}
    if date:
        params["date"] = date
    r = requests.get(f"{BASE}/api/report", params=params, timeout=30)  # GET with params [web:513]
    r.raise_for_status()
    return r.json()  # JSON body [web:515]

def get_linechart(shop_id: int, date: str) -> dict:
    r = requests.get(f"{BASE}/api/linechart", params={"shop_id": shop_id, "date": date}, timeout=30)  # GET [web:513]
    r.raise_for_status()
    return r.json()  # JSON body [web:515]

def get_piechart(shop_id: int) -> dict:
    r = requests.get(f"{BASE}/api/piechart", params={"shop_id": shop_id}, timeout=30)  # GET [web:513]
    r.raise_for_status()
    return r.json()  # JSON body [web:515]

def get_barchart(shop_id: int, date: str) -> dict:
    r = requests.get(f"{BASE}/api/barchart", params={"shop_id": shop_id, "date": date}, timeout=30)  # GET [web:513]
    r.raise_for_status()
    return r.json()  # JSON body [web:515]

# ---------------- Formatting helpers (no raw JSON in reply) ----------------
WRITE_KEYWORDS = (" add ", " create ", " update ", " delete ", " del ", " remove ", " insert ")

def is_write_intent(text: str) -> bool:
    low = f" {text.lower().strip()} "
    return any(k in low for k in WRITE_KEYWORDS)  # basic guard to keep this agent read-only [web:552]

def format_roles(roleinfo: dict) -> str:
    payload = roleinfo.get("data") if isinstance(roleinfo, dict) else roleinfo
    rows = payload if isinstance(payload, list) else (payload.get("data", []) if isinstance(payload, dict) else [])
    if not rows:
        return "No roles found."
    lines = []
    for r in rows:
        lines.append(f"- {r.get('role_name')} (rate={r.get('hrate')}, workers={r.get('total_workers')}, desc={r.get('description')})")
    return "Roles:\n" + "\n".join(lines)

def format_staff_list(staff: dict) -> str:
    payload = staff.get("data") if isinstance(staff, dict) else staff
    rows = payload if isinstance(payload, list) else (payload.get("data", []) if isinstance(payload, dict) else [])
    if not rows:
        return "No staff found."
    lines = []
    for s in rows:
        lines.append(f"- {s.get('name')} (max_week_hours={s.get('max_hours_per_week')})")
    return "Staff:\n" + "\n".join(lines)

def format_report(report: dict) -> str:
    # Generic fallback: show high-level keys if detailed schema unknown
    if not isinstance(report, dict) or not report:
        return "No report data."
    keys = ", ".join(sorted(report.keys()))
    return f"Report keys: {keys}"

def format_chart(name: str, data: dict) -> str:
    # Generic chart formatter
    if not isinstance(data, dict) or not data:
        return f"No {name} data."
    keys = ", ".join(sorted(data.keys()))
    return f"{name} data fields: {keys}"

# ---------------- Route: POST /api/agent ----------------
@agent_bp.post("/agent")
def agent():
    """
    Body: { "shop_id": int, "message": "string", "date"?: "string" }
    - Persists last 10 turns per shop in Postgres.
    - Read-only agent: blocks write intents.
    - Routes common reads to real APIs and returns human-friendly text.
    - Falls back to Groq for scoped general answers.
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415  # content-type guidance [web:513]
    data: Dict[str, Any] = request.get_json(silent=True) or {}
    shop_id = data.get("shop_id")
    message = data.get("message")
    date = data.get("date")

    if not isinstance(shop_id, int):
        return jsonify({"error": "shop_id (int) is required"}), 400  # input validation [web:513]
    if not isinstance(message, str) or not message.strip():
        return jsonify({"error": "message (string) is required"}), 400  # input validation [web:513]

    _ensure_tables()
    history = _load_last_history(shop_id, limit=10)

    lower = message.lower().strip()

    # 0) Block writes in this read-only agent
    if is_write_intent(lower):
        note = "This agent is read-only; no database changes will be performed. Ask for roles, staff, reports, or charts."
        _save_turn(shop_id, "user", f"[shop_id={shop_id}] {message.strip()}")
        _save_turn(shop_id, "assistant", note)
        return jsonify({"reply": note})

    # 1) Roles
    if any(w in lower for w in ["role info", "roles", "role list"]):
        data = get_roleinfo(shop_id)  # call real API [web:513]
        reply = format_roles(data)  # human-friendly text [web:557]
        _save_turn(shop_id, "user", f"[shop_id={shop_id}] {message.strip()}")
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    # 2) Staff
    if any(w in lower for w in ["staff view", "list staff", "employees"]):
        data = get_staff_view(shop_id)  # real API [web:513]
        reply = format_staff_list(data)  # formatted bullets [web:557]
        _save_turn(shop_id, "user", f"[shop_id={shop_id}] {message.strip()}")
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    # 3) Report/payroll
    if "report" in lower or "payroll" in lower:
        data = get_report(shop_id, date=date)  # real API [web:513]
        reply = format_report(data)  # simple readable summary [web:557]
        _save_turn(shop_id, "user", f"[shop_id={shop_id}] {message.strip()}")
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    # 4) Charts
    if "linechart" in lower or "line chart" in lower:
        if not date:
            ask = "Please provide a date (DD/MM/YY or YYYY-MM-DD) for line chart."
            _save_turn(shop_id, "user", f"[shop_id={shop_id}] {message.strip()}")
            _save_turn(shop_id, "assistant", ask)
            return jsonify({"reply": ask})
        data = get_linechart(shop_id, date)  # real API [web:513]
        reply = format_chart("Line chart", data)  # summary [web:557]
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    if "piechart" in lower or "pie chart" in lower:
        data = get_piechart(shop_id)  # real API [web:513]
        reply = format_chart("Pie chart", data)  # summary [web:557]
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    if "barchart" in lower or "bar chart" in lower:
        if not date:
            ask = "Please provide a date (YYYY-MM-DD) for barchart."
            _save_turn(shop_id, "assistant", ask)
            return jsonify({"reply": ask})
        data = get_barchart(shop_id, date)  # real API [web:513]
        reply = format_chart("Bar chart", data)  # summary [web:557]
        _save_turn(shop_id, "assistant", reply)
        return jsonify({"reply": reply})

    # 5) Otherwise: Groq fallback within scope
    user_msg = f"[shop_id={shop_id}] {message.strip()}"
    history.append({"role": "user", "content": user_msg})
    _save_turn(shop_id, "user", user_msg)

    resp = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=history,
        temperature=0.2,
    )  # Groq chat completions call [web:506]
    reply = resp.choices[0].message.content or ""
    _save_turn(shop_id, "assistant", reply)

    return jsonify({"reply": reply})
