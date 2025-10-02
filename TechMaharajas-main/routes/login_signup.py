from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Railway PostgreSQL connection
app.config['SQLALCHEMY_DATABASE_URI'] = "postgresql://postgres:XMUrbyyFxzuDqsAsIHRLovpFLmjOoyqR@shortline.proxy.rlwy.net:18073/railway"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)


# ---------------------- DATABASE MODEL ----------------------
class Shop(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    shop_name = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    start_time = db.Column(db.String(20), nullable=False)
    end_time = db.Column(db.String(20), nullable=False)


# ---------------------- UTILITY ----------------------
def validate_json(data, fields):
    return all(field in data and str(data[field]).strip() for field in fields)


# ---------------------- ROUTES ----------------------

# Check if shop exists
@app.route('/check-shop', methods=['POST'])
def check_shop():
    data = request.get_json()
    if not validate_json(data, ['shop_name']):
        return jsonify({'error': 'Shop name is required'}), 400

    exists = Shop.query.filter_by(shop_name=data['shop_name']).first() is not None
    return jsonify({'exists': exists}), 200


# Signup (Create Shop Profile)
@app.route('/signup', methods=['POST'])
def signup():
    try:
        data = request.get_json(force=True)

        required_fields = ['shop_name', 'password', 'start_time', 'end_time']
        missing = [f for f in required_fields if not str(data.get(f, '')).strip()]
        if missing:
            return jsonify({'error': f'Missing or empty fields: {missing}'}), 400

        # Check if shop already exists
        if Shop.query.filter_by(shop_name=data['shop_name']).first():
            return jsonify({'error': 'Shop name already exists'}), 400

        # Hash password
        hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')

        # Create new shop
        new_shop = Shop(
            shop_name=data['shop_name'].strip(),
            password=hashed_password,
            start_time=data['start_time'],
            end_time=data['end_time']
        )
        db.session.add(new_shop)
        db.session.commit()

        return jsonify({
            'message': 'Shop created successfully',
            'shop': {
                'shop_name': new_shop.shop_name,
                'start_time': new_shop.start_time,
                'end_time': new_shop.end_time
            }
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# Login
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not validate_json(data, ['shop_name', 'password']):
        return jsonify({'error': 'Shop name and password required'}), 400

    shop = Shop.query.filter_by(shop_name=data['shop_name']).first()
    if not shop or not bcrypt.check_password_hash(shop.password, data['password']):
        return jsonify({'error': 'Invalid credentials'}), 401

    return jsonify({
        'status': 'success',
        'shop': {
            'shop_name': shop.shop_name,
            'start_time': shop.start_time,
            'end_time': shop.end_time
        }
    }), 200


if __name__ == '__main__':
    app.run(debug=True)
