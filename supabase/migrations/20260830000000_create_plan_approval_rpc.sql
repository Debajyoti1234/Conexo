-- P1.2B.8: Creator approval + real joined plans
--
-- Adds SECURITY DEFINER RPC functions for:
--   * approve_plan_member - creator approves pending -> joined
--   * decline_plan_member - creator declines pending -> declined
--   * get_plan_joined_count - read joined member count for a plan
--
-- These complement the existing enforce_plan_member_transitions trigger
-- and enforce_plan_capacity trigger by providing a server-side entry point
-- for creator actions that bypass RLS row-level restrictions while keeping
-- authorization inside the database.

-- ============================================================================
-- 1. APPROVE
-- ============================================================================

CREATE OR REPLACE FUNCTION public.approve_plan_member(p_plan_id UUID, p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() <> (
    SELECT creator_id FROM public.plans WHERE id = p_plan_id
  ) THEN
    RAISE EXCEPTION 'Only the plan creator can approve members';
  END IF;

  UPDATE public.plan_members
  SET status = 'joined', updated_at = now()
  WHERE plan_id = p_plan_id
    AND user_id = p_user_id
    AND status = 'pending';
END;
$$;

-- ============================================================================
-- 2. DECLINE
-- ============================================================================

CREATE OR REPLACE FUNCTION public.decline_plan_member(p_plan_id UUID, p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() <> (
    SELECT creator_id FROM public.plans WHERE id = p_plan_id
  ) THEN
    RAISE EXCEPTION 'Only the plan creator can decline members';
  END IF;

  UPDATE public.plan_members
  SET status = 'declined', updated_at = now()
  WHERE plan_id = p_plan_id
    AND user_id = p_user_id
    AND status = 'pending';
END;
$$;

-- ============================================================================
-- 3. JOINED COUNT HELPER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_plan_joined_count(p_plan_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.plan_members
  WHERE plan_id = p_plan_id AND status = 'joined';

  RETURN COALESCE(v_count, 0);
END;
$$;

-- ============================================================================
-- 4. GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.approve_plan_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decline_plan_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_plan_joined_count(UUID) TO authenticated;
