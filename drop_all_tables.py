import os
from typing import List
import psycopg2
from psycopg2 import sql

# Reuse the existing connection factory from schema.py
try:
    from schema import get_connection
except Exception:
    # Fallback: direct connection using DATABASE_URL
    def get_connection():
        DATABASE_URL = os.getenv('DATABASE_URL')
        if not DATABASE_URL:
            raise Exception("Set DATABASE_URL environment variable")
        return psycopg2.connect(DATABASE_URL)


def list_tables(cur) -> List[str]:
    """Return a list of table names in the public schema."""
    cur.execute("""
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY tablename
    """)
    return [r[0] for r in cur.fetchall()]


def drop_all_tables():
    """Drops all tables in the public schema using CASCADE."""
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                tables = list_tables(cur)
                if not tables:
                    print("No tables found in schema 'public'. Nothing to drop.")
                    return

                print(f"Dropping {len(tables)} tables from schema 'public' (CASCADE)...")
                for t in tables:
                    stmt = sql.SQL("DROP TABLE IF EXISTS {} CASCADE;").format(sql.Identifier(t))
                    cur.execute(stmt)
                    print(f"  - Dropped table: {t}")
        print("All tables dropped successfully.")
    except Exception as e:
        print(f"Error while dropping tables: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    drop_all_tables()
