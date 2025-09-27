from flask import Flask, request, jsonify, abort
import sqlite3
import subprocess
import shlex
from pathlib import Path
import logging
from logging.handlers import RotatingFileHandler

# ----------------------
# Configuration
# ----------------------
app = Flask(__name__)
DB = Path("data.db")
API_KEY = "supersecretkey"  # Strong secret, required for /run
ALLOWED_COMMANDS = {
    "echo": ["hello", "test"],
    "date": []
}
LOG_FILE = "app.log"

# ----------------------
# Logging Setup
# ----------------------
handler = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
handler.setFormatter(formatter)
handler.setLevel(logging.INFO)
app.logger.addHandler(handler)
app.logger.setLevel(logging.INFO)

# ----------------------
# Database Initialization
# ----------------------
def init_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            notes TEXT
        )
    """)
    # Insert initial users if table empty
    c.execute("SELECT COUNT(*) FROM users")
    if c.fetchone()[0] == 0:
        c.executemany(
            "INSERT INTO users(username, notes) VALUES(?,?)",
            [("alice","hello"),("bob","world")]
        )
    conn.commit()
    conn.close()
    app.logger.info("Database initialized successfully.")

# ----------------------
# Authentication for /run
# ----------------------
@app.before_request
def check_api_key():
    if request.endpoint == "run_cmd":
        key = request.headers.get("X-API-KEY")
        if key != API_KEY:
            abort(403, description="Forbidden")

# ----------------------
# Routes
# ----------------------
@app.route("/search")
def search():
    q = request.args.get("q", "").strip()
    try:
        conn = sqlite3.connect(DB)
        c = conn.cursor()
        c.execute("SELECT id, username, notes FROM users WHERE username LIKE ?", (f"%{q}%",))
        rows = c.fetchall()
        conn.close()
        return jsonify({"results": [{"id": r[0], "username": r[1], "notes": r[2]} for r in rows]})
    except Exception as e:
        app.logger.error(f"Database error: {e}")
        return jsonify({"error": "Database query failed"}), 500

@app.route("/run")
def run_cmd():
    cmd = request.args.get("cmd", "").strip()
    if not cmd:
        return jsonify({"error": "No command provided"}), 400

    try:
        parts = shlex.split(cmd)
    except ValueError as e:
        return jsonify({"error": f"Invalid command syntax: {e}"}), 400

    if parts[0] not in ALLOWED_COMMANDS:
        return jsonify({"error": "Command not allowed"}), 403

    # Check arguments if whitelist is defined
    allowed_args = ALLOWED_COMMANDS[parts[0]]
    if allowed_args and any(arg not in allowed_args for arg in parts[1:]):
        return jsonify({"error": "One or more arguments are not allowed"}), 403

    try:
        proc = subprocess.run(parts, capture_output=True, text=True)
        return jsonify({
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
            "returncode": proc.returncode
        })
    except Exception as e:
        app.logger.error(f"Command execution failed: {e}")
        return jsonify({"error": "Command execution failed"}), 500

# ----------------------
# Main
# ----------------------
if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=False)
