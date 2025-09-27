from flask import Flask, request, jsonify
import sqlite3
import subprocess

app = Flask(__name__)
DB = "data.db"

def init_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, notes TEXT)")
    c.execute("INSERT OR IGNORE INTO users(id, username, notes) VALUES(1,'alice','hello'),(2,'bob','world')")
    conn.commit()
    conn.close()

@app.route("/search")
def search():
    q = request.args.get("q","")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    # FIX: parameterized query prevents SQL injection
    c.execute("SELECT id, username, notes FROM users WHERE username LIKE ?", (f"%{q}%",))
    rows = c.fetchall()
    conn.close()
    return jsonify(rows)

@app.route("/run")
def run_cmd():
    # FIX: disallow arbitrary shell. Only allow whitelisted commands.
    cmd = request.args.get("cmd", "")
    allowed = {"echo": ["hello","test"], "date": []}
    parts = cmd.split()
    if not parts or parts[0] not in allowed:
        return "Not allowed", 403
    proc = subprocess.run([parts[0]] + parts[1:], capture_output=True, text=True)
    return proc.stdout or proc.stderr

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
