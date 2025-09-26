# app.py
from flask import Flask
from routes.barchart import barchart_bp
from routes.piechart import piechart_bp

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello, this is the Home route!"

# Register blueprints
app.register_blueprint(barchart_bp)
app.register_blueprint(piechart_bp)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)

