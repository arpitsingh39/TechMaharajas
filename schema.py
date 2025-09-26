import psycopg2
import os

DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:XMUrbyyFxzuDqsAsIHRLovpFLmjOoyqR@shortline.proxy.rlwy.net:18073/railway')


def get_connection():
    if not DATABASE_URL:
        raise Exception("Set DATABASE_URL environment variable")
    conn = psycopg2.connect(DATABASE_URL)
    return conn


def create_tables_and_update_schema():
    """
    Create/ensure the requested normalized schema exists and apply ALTERs safely.
    This is idempotent and will work on an empty or existing database.
    """

    commands = (
        # Base: shops (used by roles, staff, coverage_requirements, scheduling_policies, schedule_runs)
        """
        CREATE TABLE IF NOT EXISTS shops (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            open_time TIME NOT NULL DEFAULT TIME '09:00',
            close_time TIME NOT NULL DEFAULT TIME '17:00',
            open_days SMALLINT[] DEFAULT ARRAY[0,1,2,3,4,5,6]
        );
        """,

        # Users table for schedule_runs.requested_by
        """
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            role VARCHAR(50),
            email VARCHAR(100) UNIQUE NOT NULL,
            phone VARCHAR(20),
            password_hash VARCHAR(128)
        );
        """,

        # Roles per shop
        """
        CREATE TABLE IF NOT EXISTS roles (
            id SERIAL PRIMARY KEY,
            shop_id INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
            role_name VARCHAR(50) NOT NULL,
            description VARCHAR(200)
        );
        """,

        # Staff belonging to a shop
        """
        CREATE TABLE IF NOT EXISTS staff (
            id SERIAL PRIMARY KEY,
            shop_id INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
            name VARCHAR(100) NOT NULL,
            contact_email VARCHAR(100),
            contact_phone VARCHAR(20),
            availability JSONB,
            max_hours_per_day INTEGER
        );
        """,

        # 1) Normalize availability
        """
        CREATE TABLE IF NOT EXISTS staff_availability (
            id SERIAL PRIMARY KEY,
            staff_id INTEGER NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
            day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
            start_time TIME NOT NULL,
            end_time   TIME NOT NULL,
            UNIQUE (staff_id, day_of_week, start_time, end_time)
        );
        """,

        # 2) Role eligibility + optional per-role pay
        """
        CREATE TABLE IF NOT EXISTS staff_roles (
            staff_id INTEGER NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
            role_id  INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
            hourly_rate NUMERIC(10,2),
            PRIMARY KEY (staff_id, role_id)
        );
        """,

        # 3) Demand to satisfy (AI target)
        """
        CREATE TABLE IF NOT EXISTS coverage_requirements (
            id SERIAL PRIMARY KEY,
            shop_id INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
            role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
            date DATE NOT NULL,
            start_time TIME NOT NULL,
            end_time TIME NOT NULL,
            required_count INTEGER NOT NULL CHECK (required_count >= 0)
        );
        """,

        # 4) Shop scheduling policies
        """
        CREATE TABLE IF NOT EXISTS scheduling_policies (
            shop_id INTEGER PRIMARY KEY REFERENCES shops(id) ON DELETE CASCADE,
            max_hours_per_day INTEGER DEFAULT 8,
            max_hours_per_week INTEGER DEFAULT 40,
            min_rest_hours INTEGER DEFAULT 12,
            max_consecutive_days INTEGER DEFAULT 6,
            time_step_minutes INTEGER DEFAULT 60
        );
        """,

        # 5) Schedule run metadata
        """
        CREATE TABLE IF NOT EXISTS schedule_runs (
            id SERIAL PRIMARY KEY,
            shop_id INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
            requested_by INTEGER REFERENCES users(id),
            requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            horizon_start DATE NOT NULL,
            horizon_end DATE NOT NULL,
            ai_provider VARCHAR(50),
            model VARCHAR(100),
            parameters JSONB,
            status VARCHAR(20) DEFAULT 'draft',
            result JSONB
        );
        """,

        # Shifts table (created already with desired columns and types)
        """
        CREATE TABLE IF NOT EXISTS shifts (
            id SERIAL PRIMARY KEY,
            staff_id INTEGER NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
            role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
            shift_start TIMESTAMPTZ NOT NULL,
            shift_end   TIMESTAMPTZ NOT NULL,
            status VARCHAR(20),
            schedule_run_id INTEGER REFERENCES schedule_runs(id),
            break_minutes INTEGER DEFAULT 0,
            notes TEXT
        );
        """,

        # 6) Improve shifts to link runs and time zone safety (no-op if created above)
        """
        ALTER TABLE IF EXISTS shifts
          ADD COLUMN IF NOT EXISTS schedule_run_id INTEGER REFERENCES schedule_runs(id);
        """,
        """
        ALTER TABLE IF EXISTS shifts
          ALTER COLUMN shift_start TYPE TIMESTAMPTZ USING shift_start::timestamptz,
          ALTER COLUMN shift_end   TYPE TIMESTAMPTZ USING shift_end::timestamptz;
        """,
        """
        ALTER TABLE IF EXISTS shifts
          ADD COLUMN IF NOT EXISTS break_minutes INTEGER DEFAULT 0,
          ADD COLUMN IF NOT EXISTS notes TEXT;
        """,

        # Ensure holidays exists minimally
        """
        CREATE TABLE IF NOT EXISTS holidays (
            id SERIAL PRIMARY KEY,
            staff_id INTEGER REFERENCES staff(id) ON DELETE CASCADE,
            holiday_date DATE,
            description TEXT
        );
        """,
        # 7) Expand holidays to ranges and workflow
        """
        ALTER TABLE IF EXISTS holidays
          ADD COLUMN IF NOT EXISTS start_date DATE,
          ADD COLUMN IF NOT EXISTS end_date DATE,
          ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending';
        """,
    )

    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                for command in commands:
                    cur.execute(command)
        print("Database schema dropped and recreated/updated successfully.")
    except Exception as e:
        print(f"Error updating schema: {e}")
    finally:
        conn.close()


def get_shops():
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, name, open_time, close_time, open_days FROM shops")
                rows = cur.fetchall()
                shops = []
                for row in rows:
                    shops.append({
                        'id': row[0],
                        'name': row[1],
                        'open_time': row[2].strftime('%H:%M:%S') if row[2] is not None else None,
                        'close_time': row[3].strftime('%H:%M:%S') if row[3] is not None else None,
                        'open_days': row[4]
                    })
                return shops
    finally:
        conn.close()


# Example usage
if __name__ == "__main__":
    create_tables_and_update_schema()
    try:
        print("Current shops:", get_shops())
    except Exception as e:
        # shops table may be empty or not yet populated; don't fail the run
        print(f"Note: could not list shops: {e}")
