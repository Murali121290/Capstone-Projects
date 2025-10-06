from flask import Flask, request, jsonify
import sqlite3
import subprocess
import re
import os
import json
from pathlib import Path

app = Flask(__name__)
app.debug = False  # safe for production

DB_FILE = "app.db"
UPLOAD_DIR = Path("/tmp/uploads").resolve()

# initialize db (same as vulnerable, but use parameterized queries below)
def init_db():
    if not os.path.exists(DB_FILE):
        conn = sqlite3.connect(DB_FILE)
        cur = conn.cursor()
        cur.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
        cur.execute("INSERT INTO users (name, email) VALUES (?, ?)", ("Alice", "alice@example.com"))
        cur.execute("INSERT INTO users (name, email) VALUES (?, ?)", ("Bob", "bob@example.com"))
        conn.commit()
        conn.close()

init_db()
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# 1) SQL injection fixed with parameterized queries
@app.route("/user")
def user():
    user_id = request.args.get("id", "1")
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.execute("SELECT id, name, email FROM users WHERE id = ?", (user_id,))
    row = cur.fetchone()
    conn.close()
    return jsonify(row=row)

# 2) OS command injection fixed: validate host + use subprocess list
_host_regex = re.compile(r'^[\w\.-]+$')
@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    if not _host_regex.match(host):
        return "invalid host", 400
    try:
        out = subprocess.run(["ping", "-c", "1", host], capture_output=True, text=True, timeout=5)
        return out.stdout
    except subprocess.SubprocessError:
        return "ping failed", 500

# 3) Unsafe deserialization fixed: accept JSON only
@app.route("/loadjson", methods=["POST"])
def loadjson():
    try:
        obj = request.get_json(force=True)
    except Exception:
        return "invalid json", 400
    # validate structure if needed
    return jsonify(type=str(type(obj)), content=obj)

# 4) Path traversal fix using path resolve
@app.route("/view")
def view():
    fname = request.args.get("file", "")
    target = (UPLOAD_DIR / fname).resolve()
    if not str(target).startswith(str(UPLOAD_DIR)):
        return "forbidden", 403
    if not target.exists() or not target.is_file():
        return "not found", 404
    return target.read_text()

# 5) Secrets from environment
import os
API_KEY = os.environ.get("API_KEY", "unset")

@app.route("/secret")
def secret():
    return jsonify(api_key_set = (API_KEY != "unset"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
