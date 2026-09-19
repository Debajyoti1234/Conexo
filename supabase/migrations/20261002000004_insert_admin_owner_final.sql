-- Phase 1A: Insert initial admin owner record.
-- Uses SECURITY DEFINER with row_security bypass to ensure the INSERT succeeds
-- regardless of migration runner role.
-- Idempotent: safe to run multiple times.

CREATE OR REPLACE FUNCTION public._insert_initial_admin_owner()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('row_security', 'off', true);
  INSERT INTO public.admin_accounts (admin_user_id, role)
  VALUES (
    '416e188c-bf28-401f-883c-e74830d3e6f0'::UUID,
    'owner'
  )
  ON CONFLICT (admin_user_id) DO NOTHING;
END;
$$;

SELECT public._insert_initial_admin_owner();