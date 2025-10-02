# Tech Maharaja

Flask + Postgres starter for shop/staff/shift scheduling.

Key features:
- Postgres schema with shops, roles, staff, users, shifts
- Shifts include a human-friendly business_id generated from the shift date: YYYYMMDD-#### (per-day sequence)

Quick start
- Set DATABASE_URL in your environment
- Install deps and create tables by running the schema module

Try it
1. Install requirements
2. Create tables (and the date-based ID trigger)
3. Run the Flask app locally

Notes
- business_id is unique and auto-generated from shift_start; you can optionally supply your own when inserting a shift.