-- P1.2B.15: Plan join request cancellation
--
-- Adds a `cancelled` status to plan_members and a SECURITY DEFINER RPC
-- so users can cancel their own pending join requests without host action.
--
-- Cancellation is intentionally distinct from `declined`:
--   * `declined` = host rejected a pending request
--   * `cancelled` = member withdrew their own pending request
--
-- The row is preserved (not deleted) so:
--   * membership history remains auditable
--   * the user can re-join later via `request_to_join` (cancelled -> pending)
--   * the host no longer sees an actionable pending request

-- ============================================================================
-- 1. EXTEND STATUS CHECK CONSTRAINT
-- ============================================================================

ALTER TABLE public.plan_members
  DROP CONSTRAINT IF EXISTS plan_members_status_check;

ALTER TABLE public.plan_members
  ADD CONSTRAINT plan_members_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'joined'::text,
    'declined'::text,
    'left'::text,
    'removed'::text,
    'cancelled'::text
  ]));

-- ============================================================================
-- 2. EXTEND STATE-MACHINE TRIGGER
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

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- pending -> joined (direct join or invite accepted)
  IF OLD.status = 'pending' AND NEW.status = 'joined' THEN
    RETURN NEW;
  END IF;

  -- pending -> declined (host rejection)
  IF OLD.status = 'pending' AND NEW.status = 'declined' THEN
    RETURN NEW;
  END IF;

  -- pending -> cancelled (self cancellation)
  IF OLD.status = 'pending' AND NEW.status = 'cancelled' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can cancel their own request';
    END IF;
    RETURN NEW;
  END IF;

  -- joined -> left (self only)
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

  -- Self-reactivation: cancelled -> pending (re-join after cancellation)
  IF OLD.status = 'cancelled' AND NEW.status = 'pending' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can rejoin';
    END IF;
    RETURN NEW;
  END IF;

  -- Self-reactivation: removed/left/declined/cancelled -> joined (accept invitation)
  IF OLD.status IN ('removed', 'left', 'declined', 'cancelled') AND NEW.status = 'joined' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can rejoin';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid plan member status transition: % → %', OLD.status, NEW.status;
END;
$$;

-- ============================================================================
-- 3. CANCEL JOIN REQUEST RPC
-- ============================================================================
--
-- Allows the current user to cancel their own pending join request.
-- Idempotent: if the row is already cancelled/not-pending, it is a no-op.

CREATE OR REPLACE FUNCTION public.cancel_plan_join_request(p_plan_id UUID)
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

  IF v_existing_status IS NULL THEN
    RETURN;
  END IF;

  IF v_existing_status <> 'pending' THEN
    RETURN;
  END IF;

  UPDATE public.plan_members
  SET status = 'cancelled', updated_at = now()
  WHERE plan_id = p_plan_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_plan_join_request(UUID) TO authenticated;
