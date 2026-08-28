-- P1.2B.13: Removed-member rejoin fix
--
-- Root cause:
--   * When a member is removed (status = 'removed'), their plan_members row
--     still exists. The UNIQUE(plan_id, user_id) constraint blocks a new
--     INSERT, so requestToJoin silently fails.
--   * The enforce_plan_member_transitions trigger only allows joined->removed
--     (creator) and does not allow removed/left/declined -> pending/joined,
--     so accept_plan_invitation also fails for reactivation.
--
-- Fix:
--   * Extend the state-machine trigger to permit self-reactivation:
--       removed/left/declined -> pending (re-request)
--       removed/left/declined -> joined (accept invitation)
--     Only allowed when auth.uid() = user_id.
--   * Add a SECURITY DEFINER request_to_join RPC that inserts a new pending
--     membership or reactivates an existing removed/left/declined row.
--     This avoids the unique-constraint conflict on the client path.

-- ============================================================================
-- 1. EXTEND STATE-MACHINE TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.enforce_plan_member_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role <> OLD.role THEN
    RAISE EXCEPTION 'role is immutable';
  END IF;
  IF NEW.plan_id <> OLD.plan_id THEN
    RAISE EXCEPTION 'plan_id is immutable';
  END IF;
  IF NEW.user_id <> OLD.user_id THEN
    RAISE EXCEPTION 'user_id is immutable';
  END IF;
  IF NEW.joined_at <> OLD.joined_at THEN
    RAISE EXCEPTION 'joined_at is immutable';
  END IF;
  IF NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable';
  END IF;

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- pending -> joined (direct join or invite accepted)
  IF OLD.status = 'pending' AND NEW.status = 'joined' THEN
    RETURN NEW;
  END IF;

  -- pending -> declined
  IF OLD.status = 'pending' AND NEW.status = 'declined' THEN
    RETURN NEW;
  END IF;

  -- joined -> left (self only; RLS also enforces auth.uid() = user_id)
  IF OLD.status = 'joined' AND NEW.status = 'left' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can leave';
    END IF;
    RETURN NEW;
  END IF;

  -- joined -> removed (creator only)
  IF OLD.status = 'joined' AND NEW.status = 'removed' THEN
    IF auth.uid() <> (
      SELECT creator_id FROM public.plans WHERE id = NEW.plan_id
    ) THEN
      RAISE EXCEPTION 'Only the creator can remove a member';
    END IF;
    RETURN NEW;
  END IF;

  -- Self-reactivation: removed/left/declined -> pending (re-join request)
  IF OLD.status IN ('removed', 'left', 'declined') AND NEW.status = 'pending' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can rejoin';
    END IF;
    RETURN NEW;
  END IF;

  -- Self-reactivation: removed/left/declined -> joined (accept invitation)
  IF OLD.status IN ('removed', 'left', 'declined') AND NEW.status = 'joined' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can rejoin';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid plan member status transition: % → %', OLD.status, NEW.status;
END;
$$;

-- ============================================================================
-- 2. REQUEST-TO-JOIN RPC
-- ============================================================================
--
-- Handles both first-time join requests and re-requests after removal/leave.
-- Because plan_members has UNIQUE(plan_id, user_id), a removed row blocks a
-- naive INSERT. This RPC checks the existing status first and either inserts
-- a new pending row or reactivates an existing removed/left/declined row.

CREATE OR REPLACE FUNCTION public.request_to_join(p_plan_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_status TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT status INTO v_existing_status
  FROM public.plan_members
  WHERE plan_id = p_plan_id AND user_id = auth.uid();

  IF v_existing_status = 'pending' THEN
    RETURN;
  END IF;

  IF v_existing_status = 'joined' THEN
    RETURN;
  END IF;

  IF v_existing_status IS NULL THEN
    INSERT INTO public.plan_members (plan_id, user_id, role, status, joined_at, updated_at)
    VALUES (p_plan_id, auth.uid(), 'member', 'pending', now(), now());
    RETURN;
  END IF;

  -- removed, left, declined → reactivate as pending
  UPDATE public.plan_members
  SET status = 'pending', updated_at = now()
  WHERE plan_id = p_plan_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_to_join(UUID) TO authenticated;
