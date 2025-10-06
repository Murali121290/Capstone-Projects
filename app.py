from flask import Flask, request
import sqlite3
import os
import pickle

app = Flask(__name__)
app.debug = True  # INTENTIONAL: insecure in production

DB_FILE = "app.db"

# --- Setup a trivial DB for demo ---
def init_db():
    if not os.path.exists(DB_FILE):
        conn = sqlite3.connect(DB_FILE)
        cur = conn.cursor()
        cur.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
        cur.execute("INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')")
        cur.execute("INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com')")
        conn.commit()
        conn.close()

init_db()

# 1) SQL Injection (vulnerable)
@app.route("/user")
def user():
    # attacker-controlled parameter used directly in SQL
    user_id = request.args.get("id", "1")
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    # VULNERABLE: direct interpolation
    cur.execute(f"SELECT id, name, email FROM users WHERE id = {user_id}")
    row = cur.fetchone()
    conn.close()
    return str(row)

# 2) OS command injection (vulnerable)
@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # VULNERABLE: shell command built from user input
    return os.popen(f"ping -c 1 {host}").read()

# 3) Unsafe deserialization (vulnerable)
@app.route("/load", methods=["POST"])
def load():
    data = request.data
    # VULNERABLE: pickle loads on untrusted input
    obj = pickle.loads(data)
    return f"Loaded object type: {type(obj)}"

# 4) Path traversal (vulnerable)
@app.route("/view")
def view():
    fname = request.args.get("file", "notes.txt")
    # VULNERABLE: no normalization -> path traversal possible
    path = os.path.join("/tmp/uploads", fname)
    with open(path, "r") as f:
        return f.read()

# 5) Hardcoded secret (vulnerable)
API_KEY = "SUPERSECRET_API_KEY_123456"  # IN SOURCE

@app.route("/secret")
def secret():
    return f"API_KEY={API_KEY}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
