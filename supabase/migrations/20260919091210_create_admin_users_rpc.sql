-- Phase 1E.1A: Admin Users data layer (list + detail RPCs)
--
-- Creates two SECURITY DEFINER functions that expose user information to the
-- Admin Dashboard only. Both gate on public.is_admin() and return aggregate /
-- joined rows — never raw auth secrets.
--
-- SECURITY MODEL (mirrors Phase 1D's get_admin_overview_metrics):
--   * Verifies public.is_admin() server-side before returning any data.
--   * SECURITY DEFINER bypasses RLS for read aggregates only (no writes).
--   * EXECUTE granted to `authenticated` (the admin session) ONLY.
--   * REVOKE from PUBLIC, anon, and service_role.
--   * Does NOT modify any consumer RLS policy, consumer table, or consumer behavior.
--
-- NOTE: live_locations already has an authenticated SELECT policy; the admin
-- reads live location through these RPCs for a single, auditable data path.

-- ============================================================================
-- admin_list_users
--   Paginated, searchable, filterable Admin user list.
--   Returns one row per user plus a `total` of matching users (pre-pagination).
--   Does NOT return exact latitude/longitude (list shows freshness only).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_limit int DEFAULT 25,
  p_offset int DEFAULT 0,
  p_search text DEFAULT '',
  p_verification_status text DEFAULT '',
  p_profile_visibility text DEFAULT '',
  p_sort text DEFAULT 'newest'
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  email text,
  phone text,
  verification_status text,
  profile_visibility text,
  profile_completed boolean,
  availability_status text,
  registration_date timestamptz,
  last_sign_in_at timestamptz,
  banned_until timestamptz,
  connection_count bigint,
  report_count bigint,
  last_active_at timestamptz,
  location_updated_at timestamptz,
  location_status text,
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

  -- Sanitize pagination + sort inputs (ignore invalid values safely).
  IF p_limit < 1 THEN
    p_limit := 1;
  ELSIF p_limit > 100 THEN
    p_limit := 100;
  END IF;
  IF p_offset < 0 THEN
    p_offset := 0;
  END IF;
  IF p_sort NOT IN ('newest', 'oldest', 'name_asc', 'name_desc') THEN
    p_sort := 'newest';
  END IF;

  RETURN QUERY
  SELECT
    base.user_id,
    base.display_name,
    base.email,
    base.phone,
    base.verification_status,
    base.profile_visibility,
    base.profile_completed,
    base.availability_status,
    base.registration_date,
    base.last_sign_in_at,
    base.banned_until,
    (SELECT count(*) FROM public.connections c
     WHERE c.status = 'accepted'
       AND (c.requester_id = base.user_id OR c.recipient_id = base.user_id))::bigint AS connection_count,
    (SELECT count(*) FROM public.safety_reports s
     WHERE s.reported_user_id = base.user_id)::bigint AS report_count,
    (SELECT max(d.last_seen_at) FROM public.user_devices d
     WHERE d.user_id = base.user_id) AS last_active_at,
    ll.updated_at AS location_updated_at,
    CASE
      WHEN ll.updated_at IS NULL THEN 'none'
      WHEN ll.updated_at >= now() - interval '60 minutes' THEN 'live'
      ELSE 'stale'
    END AS location_status,
    count(*) OVER() AS total
  FROM (
    SELECT
      u.id AS user_id,
      p.display_name,
      u.email::text,
      u.phone,
      p.verification_status,
      p.profile_visibility,
      p.profile_completed,
      p.availability_status,
      u.created_at AS registration_date,
      u.last_sign_in_at,
      u.banned_until
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
    WHERE u.deleted_at IS NULL
      AND (p_search = ''
           OR p.display_name ILIKE ('%' || p_search || '%')
           OR u.email ILIKE ('%' || p_search || '%')
           OR (p_search ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
               AND u.id = p_search::uuid))
      AND (p_verification_status = '' OR p.verification_status = p_verification_status)
      AND (p_profile_visibility = '' OR p.profile_visibility = p_profile_visibility)
  ) base
  LEFT JOIN public.live_locations ll ON ll.user_id = base.user_id
  ORDER BY
    CASE WHEN p_sort = 'newest'   THEN base.registration_date END DESC NULLS LAST,
    CASE WHEN p_sort = 'oldest'   THEN base.registration_date END ASC  NULLS LAST,
    CASE WHEN p_sort = 'name_asc'  THEN base.display_name    END ASC  NULLS LAST,
    CASE WHEN p_sort = 'name_desc' THEN base.display_name    END DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ============================================================================
-- admin_get_user_detail
--   Single-user detail for the Admin User Detail screen.
--   Returns profiles + auth.users (safe identity) + live location (exact)
--   + device/activity summary + moderation aggregates.
--   NEVER returns tokens, passwords, or push tokens.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_get_user_detail(p_user_id uuid)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  email text,
  phone text,
  registration_date timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz,
  is_anonymous boolean,
  is_sso_user boolean,
  banned_until timestamptz,
  deleted_at timestamptz,
  bio text,
  interests text[],
  favorite_activities text[],
  languages text[],
  gender text,
  location text,
  social_links jsonb,
  occupation text,
  education text,
  company text,
  college text,
  hometown text,
  website text,
  about_me text,
  verification_status text,
  profile_visibility text,
  profile_completed boolean,
  date_of_birth date,
  availability_status text,
  photos jsonb,
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  location_status text,
  latest_platform text,
  latest_app_version text,
  last_active_at timestamptz,
  connection_count bigint,
  conversation_membership_count bigint,
  messages_sent_count bigint,
  safety_report_count bigint,
  block_count bigint
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

  RETURN QUERY
  SELECT
    u.id AS user_id,
    p.display_name,
    u.email::text,
    u.phone,
    u.created_at AS registration_date,
    u.last_sign_in_at,
    u.email_confirmed_at,
    u.phone_confirmed_at,
    u.is_anonymous,
    u.is_sso_user,
    u.banned_until,
    u.deleted_at,
    p.bio,
    p.interests,
    p.favorite_activities,
    p.languages,
    p.gender,
    p.location,
    p.social_links,
    p.occupation,
    p.education,
    p.company,
    p.college,
    p.hometown,
    p.website,
    p.about_me,
    p.verification_status,
    p.profile_visibility,
    p.profile_completed,
    p.date_of_birth,
    p.availability_status,
    p.photos,
    ll.latitude,
    ll.longitude,
    ll.updated_at AS location_updated_at,
    CASE
      WHEN ll.updated_at IS NULL THEN 'none'
      WHEN ll.updated_at >= now() - interval '60 minutes' THEN 'live'
      ELSE 'stale'
    END AS location_status,
    (SELECT d.platform
     FROM public.user_devices d
     WHERE d.user_id = u.id
     ORDER BY d.last_seen_at DESC NULLS LAST, d.updated_at DESC NULLS LAST
     LIMIT 1) AS latest_platform,
    (SELECT d.app_version
     FROM public.user_devices d
     WHERE d.user_id = u.id
     ORDER BY d.last_seen_at DESC NULLS LAST, d.updated_at DESC NULLS LAST
     LIMIT 1) AS latest_app_version,
    (SELECT max(d.last_seen_at)
     FROM public.user_devices d
     WHERE d.user_id = u.id) AS last_active_at,
    (SELECT count(*) FROM public.connections c
     WHERE c.status = 'accepted'
       AND (c.requester_id = u.id OR c.recipient_id = u.id))::bigint AS connection_count,
    (SELECT count(*) FROM public.conversation_members cm
     WHERE cm.user_id = u.id)::bigint AS conversation_membership_count,
    (SELECT count(*) FROM public.messages m
     WHERE m.sender_id = u.id)::bigint AS messages_sent_count,
    (SELECT count(*) FROM public.safety_reports s
     WHERE s.reported_user_id = u.id)::bigint AS safety_report_count,
    (SELECT count(*) FROM public.blocks b
     WHERE b.blocker_id = u.id OR b.blocked_id = u.id)::bigint AS block_count
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.live_locations ll ON ll.user_id = u.id
  WHERE u.id = p_user_id;
END;
$$;

-- ============================================================================
-- Grants: EXECUTE for authenticated only; revoke from PUBLIC, anon, service_role.
-- (anon/service_role execute originates from the project default ACLs; it is
--  revoked here so the Admin-only RPC is not callable by non-admin roles.
--  Non-admin authenticated users are still blocked at runtime by is_admin().)
-- ============================================================================
REVOKE ALL ON FUNCTION public.admin_list_users(integer, integer, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_users(integer, integer, text, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_list_users(integer, integer, text, text, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_users(integer, integer, text, text, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_get_user_detail(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) TO authenticated;
