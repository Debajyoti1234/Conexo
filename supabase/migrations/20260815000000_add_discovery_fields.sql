-- Phase 9.4.3: Discovery filter completion + demo data migration

-- 1. Add display_name for People/Discovery identity.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT;

-- 2. Add availability_status for Available Now filter.
--    Allowed values: available_now, busy, offline.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS availability_status TEXT DEFAULT 'offline';

-- 3. Backfill display_name for existing rows with a safe default.
UPDATE profiles
SET display_name = 'Conexo Member'
WHERE display_name IS NULL;

-- 4. Constrain availability_status to known values.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_availability_status_check'
      AND conrelid = 'profiles'::regclass
  ) THEN
    ALTER TABLE profiles
    ADD CONSTRAINT profiles_availability_status_check
    CHECK (availability_status IN ('available_now', 'busy', 'offline'));
  END IF;
END $$;
