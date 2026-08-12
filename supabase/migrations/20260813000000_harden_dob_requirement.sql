-- Phase 9.4.1B: Production DOB Hardening

-- 1. Reconcile existing invalid rows:
--    Any row marked complete but missing DOB is downgraded to incomplete.
UPDATE profiles
SET profile_completed = false
WHERE profile_completed = true
  AND date_of_birth IS NULL;

-- 2. Add check constraint preventing completed profiles with NULL DOB.
--    Idempotent: only add if it does not already exist.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_completed_requires_dob'
      AND conrelid = 'profiles'::regclass
  ) THEN
    ALTER TABLE profiles
    ADD CONSTRAINT profiles_completed_requires_dob
    CHECK (
      profile_completed = false
      OR date_of_birth IS NOT NULL
    );
  END IF;
END $$;
