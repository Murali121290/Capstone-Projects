from flask import Flask, request, jsonify
import sqlite3
import os

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
    # VULN: SQL injection via string concatenation
    q = request.args.get("q","")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    query = f"SELECT id, username, notes FROM users WHERE username LIKE '%{q}%'"
    c.execute(query)
    rows = c.fetchall()
    conn.close()
    return jsonify(rows)

@app.route("/run")
def run_cmd():
    # VULN: command injection via os.system using user input
    cmd = request.args.get("cmd", "echo hello")
    os.system(f"{cmd}")   # DANGEROUS
    return "OK"

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
