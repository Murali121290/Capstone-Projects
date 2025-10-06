from flask import Flask, request, jsonify, abort, send_file
import sqlite3
import socket
import re
import os
import json
from pathlib import Path
from typing import Optional

app = Flask(__name__)
app.debug = False  # ensure debug mode is off in production

# --- Config ---
BASE_DIR = Path(__file__).parent.resolve()
DB_FILE = BASE_DIR / "app.db"
UPLOAD_DIR = Path(os.environ.get("UPLOAD_DIR", "/tmp/uploads")).resolve()
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
# tighten permissions where possible (best-effort)
try:
    UPLOAD_DIR.chmod(0o750)
except PermissionError:
    pass

# sanitize/validate hostnames (alphanumeric, dash, dot)
_host_regex = re.compile(r'^[A-Za-z0-9\.-]+$')

# --- DB helpers ---
def get_db_conn():
    # sqlite3 is not fully thread-safe by default; use a connection per request.
    conn = sqlite3.connect(str(DB_FILE), detect_types=sqlite3.PARSE_DECLTYPES)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    if DB_FILE.exists():
        return
    # use context manager for correct close/commit behavior
    with get_db_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL)"
        )
        cur.execute("INSERT INTO users (name, email) VALUES (?, ?)", ("Alice", "alice@example.com"))
        cur.execute("INSERT INTO users (name, email) VALUES (?, ?)", ("Bob", "bob@example.com"))

init_db()

# --- Utilities ---
def safe_resolve_within(base: Path, target: Path) -> bool:
    """
    Ensure `target.resolve()` is inside `base.resolve()`.
    Uses os.path.commonpath to avoid prefix trickiness.
    """
    try:
        base_resolved = str(base.resolve())
        target_resolved = str(target.resolve())
        return os.path.commonpath([base_resolved, target_resolved]) == base_resolved
    except Exception:
        return False

def tcp_probe(host: str, port: int = 80, timeout: float = 2.0) -> bool:
    """
    Lightweight TCP connection attempt to check reachability.
    This avoids using external 'ping' and does not require elevated privileges.
    """
    try:
        # Prefer numeric IPs or validated hostnames
        socket.setdefaulttimeout(timeout)
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False

# --- Routes ---

# 1) SQL injection: validate id and use parameterized queries
@app.route("/user")
def user():
    user_id = request.args.get("id", "1")
    try:
        # convert to int to avoid accidental string-based injection/implicit conversions
        user_id_int = int(user_id)
    except ValueError:
        return jsonify({"error": "id must be an integer"}), 400

    with get_db_conn() as conn:
        cur = conn.cursor()
        cur.execute("SELECT id, name, email FROM users WHERE id = ?", (user_id_int,))
        row = cur.fetchone()

    if not row:
        return jsonify({"error": "not found"}), 404

    # return a JSON object (not a raw tuple)
    return jsonify({"id": row["id"], "name": row["name"], "email": row["email"]})

# 2) OS command injection: replaced subprocess 'ping' with a TCP probe
@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # basic hostname validation
    if not _host_regex.fullmatch(host):
        return jsonify({"error": "invalid host"}), 400

    # prefer checking common TCP ports to test reachability instead of running system 'ping'
    # attempt port 80 then 443 (common), then fail
    for port in (80, 443, 22):
        if tcp_probe(host, port=port, timeout=1.5):
            return jsonify({"host": host, "reachable": True, "port": port})
    return jsonify({"host": host, "reachable": False}), 200

# 3) Unsafe deserialization: accept JSON only and validate its type
@app.route("/loadjson", methods=["POST"])
def loadjson():
    if not request.is_json:
        return jsonify({"error": "expected application/json"}), 400
    try:
        obj = request.get_json(silent=False)  # still raises if malformed
    except Exception:
        return jsonify({"error": "invalid json"}), 400

    # optional: validate structure (example: must be dict with 'action' key)
    if not isinstance(obj, (dict, list)):
        return jsonify({"error": "json must be object or array"}), 400

    return jsonify({"type": type(obj).__name__, "content": obj})

# 4) Path traversal fix when reading files from UPLOAD_DIR
@app.route("/view")
def view():
    fname = request.args.get("file", "")
    if not fname:
        return jsonify({"error": "file parameter required"}), 400

    # do not accept path separators in filename; treat as a basename
    safe_name = Path(fname).name
    target = (UPLOAD_DIR / safe_name)

    if not safe_resolve_within(UPLOAD_DIR, target):
        return jsonify({"error": "forbidden"}), 403

    if not target.exists() or not target.is_file():
        return jsonify({"error": "not found"}), 404

    # If you want to stream or set content-type, consider send_file/send_from_directory
    return send_file(str(target), as_attachment=False)

# 5) Secrets from environment: do not return secret value; only expose boolean presence
API_KEY = os.environ.get("API_KEY")
@app.route("/secret")
def secret():
    # avoid leaking the actual value
    return jsonify({"api_key_present": bool(API_KEY)})

# --- Run ---
if __name__ == "__main__":
    # NOTE: for production use a WSGI server (gunicorn/uwsgi) and do not use app.run
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
