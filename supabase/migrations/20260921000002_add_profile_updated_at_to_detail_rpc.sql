-- Phase 1E.3: Add profiles.updated_at to admin_get_user_detail RPC
--
-- Replaces the existing admin_get_user_detail SECURITY DEFINER function with
-- a version that also returns profiles.updated_at as profile_updated_at.
-- This is a backward-compatible addition: the new column is appended to the
-- RETURNS TABLE and the SELECT; existing callers simply read the extra field.
-- No existing column or behavior is changed.
--
-- profiles.updated_at is the best available proxy for "last verification
-- activity" since there is no dedicated verification timestamp column.

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
  block_count bigint,
  profile_updated_at timestamptz
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
     WHERE b.blocker_id = u.id OR b.blocked_id = u.id)::bigint AS block_count,
    p.updated_at AS profile_updated_at
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.live_locations ll ON ll.user_id = u.id
  WHERE u.id = p_user_id;
END;
$$;

-- Re-grant (CREATE OR REPLACE preserves grants, but be explicit per existing pattern).
REVOKE ALL ON FUNCTION public.admin_get_user_detail(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_user_detail(uuid) TO authenticated;