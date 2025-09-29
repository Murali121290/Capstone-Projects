from flask import Flask, request, jsonify
app = Flask(__name__)

# Intentionally insecure input handling to "seed" a vulnerability:
@app.route('/vulnerable', methods=['GET'])
def vulnerable():
    # naive echo of query param (seed for a security issue to be detected by Sonar)
    name = request.args.get('name', 'world')
    return f"Hello {name}"

@app.route('/')
def hello():
    return "Hello from myapp!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
