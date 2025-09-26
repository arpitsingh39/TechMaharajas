# app.py
from flask import Flask

app = Flask(__name__)

@app.route('/home')
def home():
    return "Hello, this is the Home route!"

if __name__ == '__main__':
    app.run(debug=True)
