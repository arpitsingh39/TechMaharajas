from __future__ import annotations

import os
from typing import Dict, List

from flask import Blueprint, request, jsonify
from dotenv import load_dotenv
from groq import Groq

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY missing in environment")

client = Groq(api_key=GROQ_API_KEY)

agent_memory_bp = Blueprint("agent_memory_bp", __name__, url_prefix="/api")

# In-memory history: { shop_id: [ {role, content}, ... ] }
HISTORY: Dict[int, List[Dict[str, str]]] = {}

SYSTEM_PROMPT = (
    "You are a helpful assistant restricted to a single shop. "
    "Only answer about the provided shop_id. If a request is outside this shop, say it's out of scope."
)

def _get_history(shop_id: int) -> List[Dict[str, str]]:
    if shop_id not in HISTORY:
        HISTORY[shop_id] = [{"role": "system", "content": SYSTEM_PROMPT}]
    return HISTORY[shop_id]

@agent_memory_bp.post("/agent/<int:shop_id>")
def chat(shop_id: int):
    """
    POST /api/agent/<shop_id>
    Body: { "message": "string" }
    - Keeps history in RAM per shop_id.
    - Calls Groq chat.completions and returns the assistant reply.
    """
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415
    body = request.get_json(silent=True) or {}
    message = body.get("message")
    if not isinstance(message, str) or not message.strip():
        return jsonify({"error": "message (string) is required"}), 400

    history = _get_history(shop_id)
    # Add user turn with explicit shop scope prefix to help the model
    user_msg = f"[shop_id={shop_id}] {message.strip()}"
    history.append({"role": "user", "content": user_msg})

    # Call Groq chat completions
    resp = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=history,
        temperature=0.2,
    )
    reply = resp.choices[0].message.content or ""

    # Save assistant turn and return
    history.append({"role": "assistant", "content": reply})
    return jsonify({"reply": reply, "history_len": len(history)})
