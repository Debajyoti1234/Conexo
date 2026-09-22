-- Phase 1D: Admin Dashboard Overview Metrics RPC
--
-- Creates a single SECURITY DEFINER function that returns aggregate
-- overview metrics for the Admin Dashboard.
--
-- SECURITY MODEL:
--   * Verifies public.is_admin() server-side before returning any data.
--   * SECURITY DEFINER bypasses RLS for the aggregate counts only.
--   * Returns one row of aggregate integers — never raw user/profile/report rows.
--   * GRANT EXECUTE TO authenticated only (not anon).
--   * Does NOT modify any existing RLS policy, consumer table, or consumer behavior.
--
-- METRICS RETURNED:
--   total_users, new_users_today, new_users_7d, new_users_30d,
--   verified_users, pending_verification, public_profiles, private_profiles,
--   active_plans, active_connections, total_rooms, open_reports
--
-- NOT INCLUDED (by design — no reliable persisted data exists yet):
--   active_users, suspended_banned_users

CREATE OR REPLACE FUNCTION public.get_admin_overview_metrics()
RETURNS TABLE (
  total_users BIGINT,
  new_users_today BIGINT,
  new_users_7d BIGINT,
  new_users_30d BIGINT,
  verified_users BIGINT,
  pending_verification BIGINT,
  public_profiles BIGINT,
  private_profiles BIGINT,
  active_plans BIGINT,
  active_connections BIGINT,
  total_rooms BIGINT,
  open_reports BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Authorization gate: only users present in public.admin_accounts may
  --    execute this function. A normal consumer session is rejected here
  --    before any protected aggregate data is touched.
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- 2. Return one row of aggregate metrics only.
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.profiles) AS total_users,

    (SELECT COUNT(*) FROM public.profiles
     WHERE created_at >= CURRENT_DATE) AS new_users_today,

    (SELECT COUNT(*) FROM public.profiles
     WHERE created_at >= now() - interval '7 days') AS new_users_7d,

    (SELECT COUNT(*) FROM public.profiles
     WHERE created_at >= now() - interval '30 days') AS new_users_30d,

    (SELECT COUNT(*) FROM public.profiles
     WHERE verification_status = 'verified') AS verified_users,

    (SELECT COUNT(*) FROM public.profiles
     WHERE verification_status = 'pending') AS pending_verification,

    (SELECT COUNT(*) FROM public.profiles
     WHERE profile_visibility = 'public') AS public_profiles,

    (SELECT COUNT(*) FROM public.profiles
     WHERE profile_visibility = 'private') AS private_profiles,

    (SELECT COUNT(*) FROM public.plans
     WHERE status = 'active') AS active_plans,

    (SELECT COUNT(*) FROM public.connections
     WHERE status = 'accepted') AS active_connections,

    (SELECT COUNT(*) FROM public.conversations) AS total_rooms,

    (SELECT COUNT(*) FROM public.safety_reports
     WHERE status IN ('pending', 'reviewing')) AS open_reports;
END;
$$;

-- 3. Grant execute to authenticated role only.
--    Anon (unauthenticated) callers are rejected by the is_admin() gate
--    and by the lack of a grant below.
REVOKE ALL ON FUNCTION public.get_admin_overview_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_overview_metrics() TO authenticated;2