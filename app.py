from flask import Flask

# Create Flask app instance
app = Flask(__name__)

# Define a simple route
@app.route('/')
def home():
    return "✅ Welcome to the Flask App!"

@app.route('/')
def home():
    return "✅ Welcome to the Flask App!"

@app.route('/')
def home():
    return "✅ Welcome to the Flask App!"

@app.route('/')
def home():
    return "✅ Welcome to the Flask App!"

# Run the app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
