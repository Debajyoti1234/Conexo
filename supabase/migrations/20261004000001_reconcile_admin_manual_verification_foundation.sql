-- Phase 1E.4E Recovery: Admin Manual Verification Backend Foundation
--
-- This migration reconciles the production admin verification foundation
-- that was defined in source but never applied to production.
--
-- What was missing in production:
--   * public.admin_verification_audit table
--   * public.admin_approve_verification function (existing Admin UI depends on it)
--   * public.admin_list_manual_verifications function
--   * public.admin_get_manual_verification function
--   * public.admin_approve_manual_verification function
--   * public.admin_reject_manual_verification function
--
-- All RPCs follow the existing admin security pattern:
--   * Verifies public.is_admin() server-side before any data access.
--   * SECURITY DEFINER bypasses RLS for admin actions only.
--   * GRANT EXECUTE TO authenticated only (admin session).
--   * REVOKE from PUBLIC, anon, and service_role.
--   * Does NOT modify consumer RLS, consumer tables, or consumer behavior.
--   * Acting admin identity comes from auth.uid() — never from Flutter.
--   * Does NOT expose face-verification evidence, selfie images, or secrets.
--   * Does NOT create public URLs or weaken Storage privacy.
--   * Signed URL generation is intentionally deferred to a future phase.

-- ============================================================================
-- 1. Audit table (restored — was defined in 20260921000001 but never applied)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.admin_verification_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL,
  target_user_id UUID NOT NULL,
  action TEXT NOT NULL,
  previous_status TEXT NOT NULL,
  new_status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_verification_audit_target
  ON public.admin_verification_audit(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_verification_audit_admin
  ON public.admin_verification_audit(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_verification_audit_action
  ON public.admin_verification_audit(action);

-- RLS: no direct user access; only SECURITY DEFINER admin functions write here.
ALTER TABLE public.admin_verification_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "No direct user access on admin_verification_audit"
  ON public.admin_verification_audit;
CREATE POLICY "No direct user access on admin_verification_audit"
  ON public.admin_verification_audit
  FOR ALL
  TO authenticated, anon
  USING (FALSE)
  WITH CHECK (FALSE);

-- ============================================================================
-- 2. RPC: admin_approve_verification (restored — existing Admin UI depends on it)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_approve_verification(
  p_target_user_id uuid,
  p_expected_status text
)
RETURNS TABLE (
  success boolean,
  previous_status text,
  new_status text,
  updated_at timestamptz,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_status text;
  prev_status text;
  result boolean := FALSE;
  msg text := '';
  new_updated_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT verification_status INTO current_status
  FROM public.profiles
  WHERE id = p_target_user_id;

  IF current_status IS NULL THEN
    msg := 'User not found';
  ELSIF current_status != p_expected_status THEN
    msg := 'Status changed since last load. Current: ' || current_status;
  ELSIF current_status != 'pending' THEN
    msg := 'Only pending users can be approved';
  ELSE
    prev_status := current_status;

    UPDATE public.profiles
    SET verification_status = 'verified',
        updated_at = now()
    WHERE id = p_target_user_id;

    new_updated_at := now();

    INSERT INTO public.admin_verification_audit (
      admin_user_id,
      target_user_id,
      action,
      previous_status,
      new_status
    ) VALUES (
      auth.uid(),
      p_target_user_id,
      'approve',
      prev_status,
      'verified'
    );

    result := TRUE;
    msg := 'Verification approved';
  END IF;

  RETURN QUERY SELECT result, prev_status, 'verified', new_updated_at, msg;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_approve_verification(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) TO authenticated;

-- ============================================================================
-- 3. RPC: admin_list_manual_verifications
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_list_manual_verifications(
  p_limit int DEFAULT 25,
  p_offset int DEFAULT 0,
  p_search text DEFAULT '',
  p_status text DEFAULT '',
  p_sort text DEFAULT 'pending_first'
)
RETURNS TABLE (
  request_id uuid,
  user_id uuid,
  display_name text,
  email text,
  verification_status text,
  manual_status text,
  created_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid,
  rejection_reason text,
  total bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_search text := COALESCE(p_search, '');
  v_status text := COALESCE(p_status, '');
  v_sort text := COALESCE(p_sort, 'pending_first');
  v_search_uuid uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_limit < 1 THEN
    p_limit := 1;
  ELSIF p_limit > 100 THEN
    p_limit := 100;
  END IF;
  IF p_offset < 0 THEN
    p_offset := 0;
  END IF;

  IF v_sort NOT IN ('pending_first', 'newest', 'oldest',
                     'updated_newest', 'updated_oldest',
                     'name_asc', 'name_desc') THEN
    v_sort := 'pending_first';
  END IF;

  IF v_search ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    v_search_uuid := v_search::uuid;
  END IF;

  RETURN QUERY
  SELECT
    m.id AS request_id,
    m.user_id AS user_id,
    p.display_name AS display_name,
    u.email::text AS email,
    p.verification_status AS verification_status,
    m.status AS manual_status,
    m.created_at AS created_at,
    m.reviewed_at AS reviewed_at,
    m.reviewed_by AS reviewed_by,
    m.rejection_reason AS rejection_reason,
    count(*) OVER() AS total
  FROM public.manual_verification_requests m
  JOIN public.profiles p ON p.id = m.user_id
  JOIN auth.users u ON u.id = m.user_id
  WHERE (v_status = '' OR m.status = v_status)
    AND (v_search = ''
         OR p.display_name ILIKE ('%' || v_search || '%')
         OR u.email ILIKE ('%' || v_search || '%')
         OR (v_search_uuid IS NOT NULL AND m.user_id = v_search_uuid))
  ORDER BY
    CASE WHEN v_sort = 'pending_first' THEN
      CASE m.status
        WHEN 'pending_review' THEN 1
        WHEN 'approved' THEN 2
        WHEN 'rejected' THEN 3
      END
    END ASC NULLS LAST,
    CASE WHEN v_sort IN ('pending_first', 'newest') THEN m.created_at END DESC NULLS LAST,
    CASE WHEN v_sort = 'oldest' THEN m.created_at END ASC  NULLS LAST,
    CASE WHEN v_sort = 'updated_newest' THEN m.reviewed_at END DESC NULLS LAST,
    CASE WHEN v_sort = 'updated_oldest' THEN m.reviewed_at END ASC  NULLS LAST,
    CASE WHEN v_sort = 'name_asc'  THEN p.display_name END ASC  NULLS LAST,
    CASE WHEN v_sort = 'name_desc' THEN p.display_name END DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_manual_verifications(integer, integer, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_manual_verifications(integer, integer, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_list_manual_verifications(integer, integer, text, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_manual_verifications(integer, integer, text, text, text) TO authenticated;

-- ============================================================================
-- 4. RPC: admin_get_manual_verification
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_get_manual_verification(
  p_request_id uuid
)
RETURNS TABLE (
  request_id uuid,
  user_id uuid,
  display_name text,
  email text,
  verification_status text,
  manual_status text,
  selfie_path text,
  id_front_path text,
  id_back_path text,
  created_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid,
  rejection_reason text
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
    m.id AS request_id,
    m.user_id AS user_id,
    p.display_name AS display_name,
    u.email::text AS email,
    p.verification_status AS verification_status,
    m.status AS manual_status,
    m.selfie_path AS selfie_path,
    m.id_front_path AS id_front_path,
    m.id_back_path AS id_back_path,
    m.created_at AS created_at,
    m.reviewed_at AS reviewed_at,
    m.reviewed_by AS reviewed_by,
    m.rejection_reason AS rejection_reason
  FROM public.manual_verification_requests m
  JOIN public.profiles p ON p.id = m.user_id
  JOIN auth.users u ON u.id = m.user_id
  WHERE m.id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_manual_verification(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_get_manual_verification(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_get_manual_verification(uuid) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_manual_verification(uuid) TO authenticated;

-- ============================================================================
-- 5. RPC: admin_approve_manual_verification
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_approve_manual_verification(
  p_request_id uuid,
  p_expected_status text
)
RETURNS TABLE (
  success boolean,
  previous_status text,
  new_status text,
  updated_at timestamptz,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_manual text;
  v_target_user uuid;
  v_prev_profile text;
  v_result boolean := FALSE;
  v_msg text := '';
  v_updated_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT m.status, m.user_id
    INTO v_current_manual, v_target_user
    FROM public.manual_verification_requests m
    WHERE m.id = p_request_id
    FOR UPDATE;

  IF v_current_manual IS NULL THEN
    v_msg := 'Request not found';
  ELSIF v_current_manual != p_expected_status THEN
    v_msg := 'Status changed since last load. Current: ' || v_current_manual;
  ELSIF v_current_manual != 'pending_review' THEN
    v_msg := 'Only pending_review requests can be approved';
  ELSE
    SELECT verification_status INTO v_prev_profile
    FROM public.profiles
    WHERE id = v_target_user;

    v_prev_profile := COALESCE(v_prev_profile, 'notVerified');

    UPDATE public.manual_verification_requests
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_request_id;

    UPDATE public.profiles
    SET verification_status = 'verified',
        updated_at = now()
    WHERE id = v_target_user;

    v_updated_at := now();

    INSERT INTO public.admin_verification_audit (
      admin_user_id,
      target_user_id,
      action,
      previous_status,
      new_status
    ) VALUES (
      auth.uid(),
      v_target_user,
      'manual_approve',
      v_prev_profile,
      'verified'
    );

    v_result := TRUE;
    v_msg := 'Manual verification approved';
  END IF;

  RETURN QUERY SELECT v_result, v_prev_profile, 'verified', v_updated_at, v_msg;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_approve_manual_verification(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_approve_manual_verification(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_approve_manual_verification(uuid, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_approve_manual_verification(uuid, text) TO authenticated;

-- ============================================================================
-- 6. RPC: admin_reject_manual_verification
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_reject_manual_verification(
  p_request_id uuid,
  p_expected_status text,
  p_rejection_reason text
)
RETURNS TABLE (
  success boolean,
  previous_status text,
  new_status text,
  updated_at timestamptz,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_manual text;
  v_target_user uuid;
  v_prev_profile text;
  v_result boolean := FALSE;
  v_msg text := '';
  v_updated_at timestamptz;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT m.status, m.user_id
    INTO v_current_manual, v_target_user
    FROM public.manual_verification_requests m
    WHERE m.id = p_request_id
    FOR UPDATE;

  IF v_current_manual IS NULL THEN
    v_msg := 'Request not found';
  ELSIF v_current_manual != p_expected_status THEN
    v_msg := 'Status changed since last load. Current: ' || v_current_manual;
  ELSIF v_current_manual != 'pending_review' THEN
    v_msg := 'Only pending_review requests can be rejected';
  ELSE
    SELECT verification_status INTO v_prev_profile
    FROM public.profiles
    WHERE id = v_target_user;

    v_prev_profile := COALESCE(v_prev_profile, 'notVerified');

    UPDATE public.manual_verification_requests
    SET status = 'rejected',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        rejection_reason = p_rejection_reason,
        updated_at = now()
    WHERE id = p_request_id;

    UPDATE public.profiles
    SET verification_status = 'notVerified',
        updated_at = now()
    WHERE id = v_target_user;

    v_updated_at := now();

    INSERT INTO public.admin_verification_audit (
      admin_user_id,
      target_user_id,
      action,
      previous_status,
      new_status
    ) VALUES (
      auth.uid(),
      v_target_user,
      'manual_reject',
      v_prev_profile,
      'notVerified'
    );

    v_result := TRUE;
    v_msg := 'Manual verification rejected';
  END IF;

  RETURN QUERY SELECT v_result, v_prev_profile, 'notVerified', v_updated_at, v_msg;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_reject_manual_verification(uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_reject_manual_verification(uuid, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_reject_manual_verification(uuid, text, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_reject_manual_verification(uuid, text, text) TO authenticated;