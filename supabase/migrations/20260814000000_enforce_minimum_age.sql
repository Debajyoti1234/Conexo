-- Phase 9.4.1C: Production 18+ Age Policy

-- 1. Create the age-validation function (idempotent).
CREATE OR REPLACE FUNCTION public.validate_profile_age()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL
     AND NEW.date_of_birth > (CURRENT_DATE - INTERVAL '18 years')::date
  THEN
    RAISE EXCEPTION 'User must be at least 18 years old.';
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Attach as BEFORE INSERT OR UPDATE trigger (idempotent).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_validate_profile_age'
      AND tgrelid = 'profiles'::regclass
  ) THEN
    CREATE TRIGGER trg_validate_profile_age
      BEFORE INSERT OR UPDATE OF date_of_birth
      ON profiles
      FOR EACH ROW
      EXECUTE FUNCTION public.validate_profile_age();
  END IF;
END $$;
