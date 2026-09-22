-- Phase 1E.2: Admin Verification Queue RPC
--
-- Creates a SECURITY DEFINER function that returns a paginated, searchable,
-- filterable verification queue for the Admin Dashboard.
--
-- SECURITY MODEL (mirrors Phase 1D/1E.1A admin RPCs):
--   * Verifies public.is_admin() server-side before returning any data.
--   * SECURITY DEFINER bypasses RLS for read-only access.
--   * GRANT EXECUTE TO authenticated only (admin session).
--   * REVOKE from PUBLIC, anon, and service_role.
--   * Does NOT modify any existing RLS policy, consumer table, or consumer
--     behavior. Does NOT expose face-verification evidence, selfie images,
--     private verification URLs, or any secrets.
--
-- DATA SOURCE:
--   verification_status lives on public.profiles (text: 'verified',
--   'pending', 'notVerified'). No separate verification-evidence table
--   exists; face verification is handled by an external Railway API that
--   updates profiles.verification_status directly. profiles.updated_at
--   (set via trigger on profile row changes) is the best available proxy
--   for "last verification activity" and is surfaced as `last_updated`.
--
-- METRICS:
--   A companion `total` column provides the server-computed count of
--   matching users (pre-pagination), independent of page size.

CREATE OR REPLACE FUNCTION public.admin_list_verifications(
  p_limit int DEFAULT 25,
  p_offset int DEFAULT 0,
  p_search text DEFAULT '',
  p_verification_status text DEFAULT '',
  p_sort text DEFAULT 'pending_first'
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  email text,
  verification_status text,
  registration_date timestamptz,
  last_updated timestamptz,
  total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Authorization: only users present in public.admin_accounts may run this.
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Sanitize pagination inputs.
  IF p_limit < 1 THEN
    p_limit := 1;
  ELSIF p_limit > 100 THEN
    p_limit := 100;
  END IF;
  IF p_offset < 0 THEN
    p_offset := 0;
  END IF;

  -- Validate sort: only allow known values.
  IF p_sort NOT IN ('pending_first', 'newest', 'oldest', 'updated_newest',
                    'updated_oldest', 'name_asc', 'name_desc') THEN
    p_sort := 'pending_first';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    p.display_name,
    u.email::text,
    p.verification_status,
    u.created_at AS registration_date,
    p.updated_at AS last_updated,
    count(*) OVER() AS total
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE u.deleted_at IS NULL
    AND (p_search = ''
         OR p.display_name ILIKE ('%' || p_search || '%')
         OR u.email ILIKE ('%' || p_search || '%')
         OR (p_search ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
             AND u.id = p_search::uuid))
    AND (p_verification_status = '' OR p.verification_status = p_verification_status)
  ORDER BY
    CASE WHEN p_sort = 'pending_first' THEN
      CASE p.verification_status
        WHEN 'pending'    THEN 1
        WHEN 'notVerified' THEN 2
        WHEN 'verified'   THEN 3
      END
    END ASC NULLS LAST,
    CASE WHEN p_sort IN ('pending_first', 'newest') THEN u.created_at END DESC NULLS LAST,
    CASE WHEN p_sort = 'oldest' THEN u.created_at END ASC  NULLS LAST,
    CASE WHEN p_sort = 'updated_newest' THEN p.updated_at END DESC NULLS LAST,
    CASE WHEN p_sort = 'updated_oldest' THEN p.updated_at END ASC  NULLS LAST,
    CASE WHEN p_sort = 'name_asc'  THEN p.display_name END ASC  NULLS LAST,
    CASE WHEN p_sort = 'name_desc' THEN p.display_name END DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 3. Grants: EXECUTE for authenticated only; revoke from PUBLIC, anon, service_role.
REVOKE ALL ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_verifications(integer, integer, text, text, text) TO authenticated;