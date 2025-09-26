from flask import Flask
from flask_cors import CORS

from routes.barchart import barchart_bp
from routes.piechart import piechart_bp
from routes.linechart import linechart_bp

app = Flask(__name__)

# Enable CORS for all routes and origins (no credentials)
CORS(app)  # equivalent to CORS(app, resources={r"/*": {"origins": "*"}})

@app.route("/")
def home():
    return "Hello, this is the Home route!"

# Register blueprints
app.register_blueprint(linechart_bp)
app.register_blueprint(barchart_bp)
app.register_blueprint(piechart_bp)

if __name__ == "__main__":
    # For local dev only; in production use: gunicorn -b 0.0.0.0:8080 app:app
    app.run(host="0.0.0.0", port=5000, debug=True)
