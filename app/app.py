from flask import Flask, request, jsonify
import sqlite3
import os

app = Flask(__name__)
DB = '/home/ubuntu/app.db'

# Vulnerability 1: SQL injection via string concatenation
# Vulnerability 2: insecure eval of user input when processing "calc" endpoint

@app.route('/')
def index():
    return "Vulnerable App - demo"

@app.route('/user')
def get_user():
    name = request.args.get('name', '')
    # BAD: direct string interpolation -> SQL injection
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, info TEXT)")
    conn.commit()

    # This line is intentionally vulnerable
    query = f"SELECT id, name, info FROM users WHERE name = '{name}'"
    cur.execute(query)
    rows = cur.fetchall()
    conn.close()
    return jsonify(rows)

@app.route('/calc', methods=['POST'])
def calc():
    # BAD: insecure eval of user-submitted expression
    data = request.json or {}
    expr = data.get('expr', '2+2')
    # insecure: using eval on untrusted input
    result = eval(expr)
    return jsonify({'expr': expr, 'result': result})

if __name__ == '__main__':
    # create db and seed a user
    os.makedirs('/home/ubuntu', exist_ok=True)
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, info TEXT)")
    cur.execute("INSERT OR IGNORE INTO users (id, name, info) VALUES (1, 'alice', 'admin')")
    conn.commit()
    conn.close()
    app.run(host='0.0.0.0', port=5000, debug=True)
