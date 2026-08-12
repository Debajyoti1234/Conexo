-- Phase 9.4.1: Discovery Database Prerequisites

-- 1. Add date_of_birth to profiles (idempotent)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;

-- 2. Partial index for public-profile discovery (idempotent)
CREATE INDEX IF NOT EXISTS idx_profiles_visibility_gender
  ON profiles(profile_visibility, gender)
  WHERE profile_visibility = 'public';

-- 3. Index for live-location freshness (idempotent)
CREATE INDEX IF NOT EXISTS idx_live_locations_updated_at
  ON live_locations(updated_at);

-- 4. SELECT policy for public profiles (idempotent via DO block)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles'
      AND policyname = 'Authenticated users can read public profiles'
  ) THEN
    CREATE POLICY "Authenticated users can read public profiles"
      ON profiles FOR SELECT
      USING (
        auth.role() = 'authenticated'
        AND profile_visibility = 'public'
      );
  END IF;
END $$;
