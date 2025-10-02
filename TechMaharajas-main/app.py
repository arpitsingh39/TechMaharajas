from flask import Flask
from flask_cors import CORS
from routes.role_update import role_update_bp
from routes.role_delete import role_delete_bp
from routes.staff_update import staff_update_bp
from routes.staff_delete import staff_delete_bp
from routes.barchart import barchart_bp
from routes.piechart import piechart_bp
from routes.linechart import linechart_bp
from routes.roleinfo import roleinfo_bp
from routes.addrole import addrole_bp
from routes.staff_create import staff_create_bp
from routes.staff_view import staff_view_bp
from routes.schedule import schedule_bp
from routes.report import report_bp
from routes.agent import agent_bp
from routes.availability import availability_bp
from routes.solve import solve_bp
from routes.login_signup import login_bp
# from routes.agent import agent_bp

# from routes.agent_memory import agent_memory_bp

app = Flask(__name__)

# Enable CORS for all routes and origins (no credentials)
CORS(app)  # equivalent to CORS(app, resources={r"/*": {"origins": "*"}})

@app.route("/")
def home():
    return "Hello, this is the Home route!"

# Register blueprints
app.register_blueprint(addrole_bp)
app.register_blueprint(roleinfo_bp)
app.register_blueprint(linechart_bp)
app.register_blueprint(barchart_bp)
app.register_blueprint(piechart_bp)
app.register_blueprint(staff_create_bp)
app.register_blueprint(staff_view_bp)
app.register_blueprint(schedule_bp)
app.register_blueprint(report_bp)
app.register_blueprint(role_update_bp)
app.register_blueprint(role_delete_bp)
app.register_blueprint(agent_bp)
app.register_blueprint(staff_update_bp)
app.register_blueprint(staff_delete_bp)
app.register_blueprint(solve_bp)  # exposes POST /api/availability/save
app.register_blueprint(availability_bp)  # exposes POST /api/availability/save
app.register_blueprint(login_bp)

# app.register_blueprint(agent_bp)
# app.register_blueprint(agent_memory_bp)


if __name__ == "__main__":
    # For local dev only; in production use: gunicorn -b 0.0.0.0:8080 app:app
    app.run(host="0.0.0.0", port=5000, debug=True)
