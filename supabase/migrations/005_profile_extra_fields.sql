-- Migration 005: Add missing profile columns
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Safe to run multiple times (IF NOT EXISTS guards)

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS phone      VARCHAR(20),
  ADD COLUMN IF NOT EXISTS cedula     VARCHAR(20),
  ADD COLUMN IF NOT EXISTS city       VARCHAR(100),
  ADD COLUMN IF NOT EXISTS birth_date DATE;

-- Reload PostgREST schema cache so the new columns are visible immediately
NOTIFY pgrst, 'reload schema';

-- Optional: index on cedula for identity lookups
CREATE INDEX IF NOT EXISTS idx_profiles_cedula ON profiles (cedula)
  WHERE cedula IS NOT NULL;
