-- Phase 1F.1: Admin Reports Queue RPCs
--
-- Creates two SECURITY DEFINER functions for the Admin Reports / Moderation
-- Queue:
--   1. admin_report_summary   — per-status aggregate counts
--   2. admin_list_reports     — paginated, searchable, filterable report queue
--
-- SECURITY MODEL (mirrors Phase 1D/1E/1E.2/1E.3 admin RPCs):
--   * Verifies public.is_admin() server-side before returning any data.
--   * SECURITY DEFINER bypasses RLS on safety_reports.
--   * GRANT EXECUTE TO authenticated only (admin session).
--   * REVOKE from PUBLIC, anon, and service_role.
--   * Does NOT modify any existing RLS policy, consumer table, or consumer
--     behavior. Does NOT expose screenshot_path, screenshot URLs, or any
--     service-role credentials.
--
-- DATA SOURCE:
--   safety_reports table (see 20260824000000_create_safety_tables.sql).
--   Columns: id, reporter_user_id, reported_user_id, reporter_name_snapshot,
--   reported_name_snapshot, report_type, description, screenshot_path,
--   status (default 'pending'), created_at, updated_at.
--
--   RLS prevents consumers from reading reports they didn't file. Admin RPCs
--   bypass RLS via SECURITY DEFINER after is_admin() verification.
--
-- STATUS VALUES (from safety_report_summary view, 20260825000000):
--   pending, reviewing, resolved, dismissed, action_taken

-- ============================================================================
-- 1. admin_report_summary — per-status counts for summary cards
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_report_summary()
RETURNS TABLE (
  pending_count bigint,
  reviewing_count bigint,
  resolved_count bigint,
  dismissed_count bigint,
  action_taken_count bigint,
  total_count bigint,
  open_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.safety_reports WHERE status = 'pending') AS pending_count,
    (SELECT COUNT(*) FROM public.safety_reports WHERE status = 'reviewing') AS reviewing_count,
    (SELECT COUNT(*) FROM public.safety_reports WHERE status = 'resolved') AS resolved_count,
    (SELECT COUNT(*) FROM public.safety_reports WHERE status = 'dismissed') AS dismissed_count,
    (SELECT COUNT(*) FROM public.safety_reports WHERE status = 'action_taken') AS action_taken_count,
    (SELECT COUNT(*) FROM public.safety_reports) AS total_count,
    (SELECT COUNT(*) FROM public.safety_reports WHERE status IN ('pending', 'reviewing')) AS open_count;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_report_summary() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_report_summary() FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_report_summary() FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_report_summary() TO authenticated;

-- ============================================================================
-- 2. admin_list_reports — paginated, searchable report queue
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_list_reports(
  p_limit int DEFAULT 25,
  p_offset int DEFAULT 0,
  p_search text DEFAULT '',
  p_status text DEFAULT '',
  p_sort text DEFAULT 'newest'
)
RETURNS TABLE (
  report_id uuid,
  reporter_user_id uuid,
  reporter_name_snapshot text,
  reported_user_id uuid,
  reported_name_snapshot text,
  report_type text,
  description text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
  IF p_sort NOT IN ('newest', 'oldest', 'updated_newest', 'updated_oldest') THEN
    p_sort := 'newest';
  END IF;

  RETURN QUERY
  SELECT
    sr.id AS report_id,
    sr.reporter_user_id,
    sr.reporter_name_snapshot,
    sr.reported_user_id,
    sr.reported_name_snapshot,
    sr.report_type,
    sr.description,
    sr.status,
    sr.created_at,
    sr.updated_at,
    count(*) OVER() AS total
  FROM public.safety_reports sr
  WHERE (p_search = ''
         OR sr.reporter_name_snapshot ILIKE ('%' || p_search || '%')
         OR sr.reported_name_snapshot ILIKE ('%' || p_search || '%')
         OR sr.report_type ILIKE ('%' || p_search || '%')
         OR (p_search ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
             AND (sr.reporter_user_id = p_search::uuid
                  OR sr.reported_user_id = p_search::uuid)))
    AND (p_status = '' OR sr.status = p_status)
  ORDER BY
    CASE WHEN p_sort = 'newest' THEN sr.created_at END DESC NULLS LAST,
    CASE WHEN p_sort = 'oldest' THEN sr.created_at END ASC  NULLS LAST,
    CASE WHEN p_sort = 'updated_newest' THEN sr.updated_at END DESC NULLS LAST,
    CASE WHEN p_sort = 'updated_oldest' THEN sr.updated_at END ASC  NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_reports(integer, integer, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_reports(integer, integer, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_list_reports(integer, integer, text, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_reports(integer, integer, text, text, text) TO authenticated;