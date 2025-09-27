from flask import Flask, request, jsonify
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
ALLOWED_COMMANDS = {
    "echo": ["hello", "test"],
    "date": []
}

# ----------------------
# Safe Logger Setup
# ----------------------
LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / "app.log"

logger = logging.getLogger("my_flask_app")
logger.setLevel(logging.INFO)

if not logger.hasHandlers():
    # Rotating file handler to prevent huge logs
    file_handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=3)
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # Console handler (optional)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

# ----------------------
# Database Initialization
# ----------------------
def init_db():
    try:
        conn = sqlite3.connect(DB)
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS users(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                notes TEXT
            )
        """)
        # Insert initial users only if table is empty
        c.execute("SELECT COUNT(*) FROM users")
        if c.fetchone()[0] == 0:
            c.executemany(
                "INSERT INTO users(username, notes) VALUES(?,?)",
                [("alice","hello"),("bob","world")]
            )
        conn.commit()
        conn.close()
        logger.info("Database initialized successfully.")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")

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
        logger.info(f"Search query executed for '{q}', {len(rows)} results found.")
        return jsonify({"results": [{"id": r[0], "username": r[1], "notes": r[2]} for r in rows]})
    except Exception as e:
        logger.error(f"Database query failed for search '{q}': {e}")
        return jsonify({"error": "Database query failed"}), 500

@app.route("/run")
def run_cmd():
    cmd = request.args.get("cmd", "").strip()
    if not cmd:
        logger.warning("No command provided in /run request")
        return jsonify({"error": "No command provided"}), 400

    try:
        parts = shlex.split(cmd)
    except ValueError as e:
        logger.warning(f"Invalid command syntax: {e}")
        return jsonify({"error": f"Invalid command syntax: {e}"}), 400

    if parts[0] not in ALLOWED_COMMANDS:
        logger.warning(f"Attempted to run disallowed command: {cmd}")
        return jsonify({"error": "Command not allowed"}), 403

    allowed_args = ALLOWED_COMMANDS[parts[0]]
    if allowed_args and any(arg not in allowed_args for arg in parts[1:]):
        logger.warning(f"Command arguments not allowed: {cmd}")
        return jsonify({"error": "One or more arguments are not allowed"}), 403

    try:
        proc = subprocess.run(parts, capture_output=True, text=True)
        logger.info(f"Executed command: {cmd} with return code {proc.returncode}")
        return jsonify({
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
            "returncode": proc.returncode
        })
    except Exception as e:
        logger.error(f"Command execution failed for '{cmd}': {e}")
        return jsonify({"error": "Command execution failed"}), 500

# ----------------------
# Main
# ----------------------
if __name__ == "__main__":
    init_db()
    logger.info("Starting Flask server on 0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=False)
