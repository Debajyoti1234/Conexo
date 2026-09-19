-- Phase 1A: Insert initial admin owner record via SECURITY DEFINER function.
-- The migration runner may apply SQL under a role subject to RLS.
-- SECURITY DEFINER ensures the INSERT runs with elevated privileges,
-- bypassing RLS so the initial owner row is created successfully.
-- Idempotent: safe to run multiple times.

CREATE OR REPLACE FUNCTION public._insert_initial_admin_owner()
RETURNS VOID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.admin_accounts (admin_user_id, role)
  VALUES (
    '416e188c-bf28-401f-883c-e74830d3e6f0'::UUID,
    'owner'
  )
  ON CONFLICT (admin_user_id) DO NOTHING;
$$;

SELECT public._insert_initial_admin_owner();