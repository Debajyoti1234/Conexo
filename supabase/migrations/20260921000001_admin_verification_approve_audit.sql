-- Phase 1E.3: Admin Verification Audit Table + Approve RPC
--
-- Creates an audit table for Admin verification actions and a SECURITY
-- DEFINER RPC to approve (pending → verified) verification requests.
--
-- SECURITY MODEL (mirrors Phase 1D/1E.1A admin RPCs):
--   * Verifies public.is_admin() server-side before any data access.
--   * SECURITY DEFINER bypasses RLS for read/write admin actions only.
--   * GRANT EXECUTE TO authenticated only (admin session).
--   * REVOKE from PUBLIC, anon, and service_role.
--   * Does NOT modify consumer RLS, consumer tables, or consumer behavior.
--   * Does NOT expose face-verification evidence, selfie images, or secrets.
--   * Acting admin identity comes from auth.uid() — never from Flutter input.
--
-- ALLOWED TRANSITIONS:
--   approve: pending → verified only.
--   notVerified is the default/initial state, NOT an explicit rejection.
--   The task instructions explicitly prohibit treating notVerified as rejection.
--
-- CONCURRENCY:
--   The caller provides p_expected_status. The RPC verifies the current
--   database status still matches before transiting. If another process
--   changed the status first, the action is rejected with a conflict message.

-- ============================================================================
-- Audit table
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

-- ============================================================================
-- RPC: admin_approve_verification
--   Moves a user from 'pending' → 'verified'.
--   Rejects non-pending users, non-admin callers, and stale expected status.
--   Creates an audit record. Returns the resulting status + updated_at.
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
  -- 1. Authorization: only admins may call this.
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- 2. Read current verification status.
  SELECT verification_status INTO current_status
  FROM public.profiles
  WHERE id = p_target_user_id;

  IF current_status IS NULL THEN
    msg := 'User not found';
  ELSIF current_status != p_expected_status THEN
    -- Concurrency guard: status changed since the client last loaded it.
    msg := 'Status changed since last load. Current: ' || current_status;
  ELSIF current_status != 'pending' THEN
    -- Only pending → verified is allowed.
    msg := 'Only pending users can be approved';
  ELSE
    prev_status := current_status;

    -- 3. Perform the transition.
    UPDATE public.profiles
    SET verification_status = 'verified',
        updated_at = now()
    WHERE id = p_target_user_id;

    new_updated_at := now();

    -- 4. Audit record (admin identity from auth.uid(), not from Flutter).
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

  -- 5. Return the result to the client (never raw profile rows).
  RETURN QUERY SELECT result, prev_status, 'verified', new_updated_at, msg;
END;
$$;

-- Grants
REVOKE ALL ON FUNCTION public.admin_approve_verification(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) FROM service_role;
GRANT EXECUTE ON FUNCTION public.admin_approve_verification(uuid, text) TO authenticated;