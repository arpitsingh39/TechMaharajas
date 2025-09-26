from __future__ import annotations

import os
import psycopg2

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:XMUrbyyFxzuDqsAsIHRLovpFLmjOoyqR@shortline.proxy.rlwy.net:18073/railway",
)

LIST_TABLES_SQL = """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
"""

# Metadata-only columns + types (works even if table has no rows)
COLUMNS_META_SQL = """
SELECT c.column_name,
       c.udt_name AS pg_type,     -- canonical underlying type name (e.g., int4, text, timestamptz)
       c.is_nullable,
       c.data_type                -- SQL standard name (e.g., integer, text)
FROM information_schema.columns c
WHERE c.table_schema = %s AND c.table_name = %s
ORDER BY c.ordinal_position;
"""

def resolve_type_names(conn, oids: list[int]) -> list[str]:
    if not oids:
        return []
    uniq = sorted({int(o) for o in oids if o is not None})
    if not uniq:
        return ["unknown"] * len(oids)
    with conn.cursor() as cur:
        cur.execute("SELECT oid, typname FROM pg_type WHERE oid = ANY(%s)", (uniq,))
        rows = cur.fetchall()
    m = {oid: name for oid, name in rows}
    return [m.get(int(o), "unknown") if o is not None else "unknown" for o in oids]

def dump_table_rows(conn, schema: str, table: str, limit: int = 50) -> list[str]:
    # Fetch up to 'limit' rows to avoid huge dumps; include types
    with conn.cursor() as cur:
        cur.execute(f'SELECT * FROM "{schema}"."{table}" LIMIT %s', (limit,))
        rows = cur.fetchall()
        col_desc = cur.description or []
    if not col_desc:
        return []
    col_names = [d.name for d in col_desc]
    type_names = resolve_type_names(conn, [d.type_code for d in col_desc])

    out = []
    for row in rows:
        parts = []
        for name, val, pg_type in zip(col_names, row, type_names):
            py_type = type(val).__name__ if val is not None else "NoneType"
            parts.append(f"{name}: {pg_type}/{py_type}={repr(val)}")
        out.append(f"{schema}.{table}(" + ", ".join(parts) + ")")
    return out

def dump_table_schema_as_str(conn, schema: str, table: str) -> str:
    # Schema-only signature string if no data rows exist
    with conn.cursor() as cur:
        cur.execute(COLUMNS_META_SQL, (schema, table))
        cols = cur.fetchall()
    if not cols:
        return f"{schema}.{table}()"
    parts = []
    for name, pg_type, is_nullable, data_type in cols:
        null = "nullable" if is_nullable == "YES" else "not-null"
        parts.append(f"{name}: {pg_type}/{data_type} ({null})")
    return f"{schema}.{table}[" + ", ".join(parts) + "]"

def main():
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn.cursor() as cur:
            cur.execute(LIST_TABLES_SQL)
            tables = cur.fetchall()

        for schema, table in tables:
            # Try to dump up to 50 rows with types
            rows = dump_table_rows(conn, schema, table, limit=50)
            if rows:
                for line in rows:
                    print(line)
            else:
                # No rows: print schema signature with column types
                print(dump_table_schema_as_str(conn, schema, table))
    finally:
        conn.close()

if __name__ == "__main__":
    main()
