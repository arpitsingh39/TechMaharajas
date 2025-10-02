-- Migration: add password_hash column to shops and backfill from password if present
-- This file is idempotent: it checks for column existence before altering the table.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'shops' AND column_name = 'password_hash'
    ) THEN
        ALTER TABLE shops ADD COLUMN password_hash text;
    END IF;
END$$;

-- If a legacy 'password' column exists, copy non-null values into password_hash
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'shops' AND column_name = 'password'
    ) THEN
        UPDATE shops SET password_hash = password WHERE password IS NOT NULL AND (password_hash IS NULL OR password_hash = '');
    END IF;
END$$;

-- You can run this with: psql "$DBURL" -f migrations/001_add_password_hash.sql
