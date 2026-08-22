-- Phase 3.1B: Plans Backend Security Fix
--
-- Corrective migration for P0/P1 findings in P1.1:
--   * P0-1: Requester self-join bypass (INSERT allowed status='joined')
--   * P0-2: Unauthorized pending→joined transition
--   * P0-3: Private Plan visibility missing for accepted Connections
--   * P1-1: Capacity not enforced
--
-- Additive and corrective only — no unrelated tables modified.

-- ============================================================================
-- 1. FIX: Restrict plan_members INSERT to pending only
-- ============================================================================
--
-- A normal authenticated user must NEVER be able to self-insert as 'joined'.
-- The creator's automatic membership is created by a SECURITY DEFINER trigger
-- and bypasses RLS entirely.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can insert own membership'
  ) THEN
    DROP POLICY "Users can insert own membership" ON public.plan_members;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can insert own pending membership'
  ) THEN
    CREATE POLICY "Users can insert own pending membership"
      ON public.plan_members FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        AND role = 'member'
        AND status = 'pending'
      );
  END IF;
END $$;

-- ============================================================================
-- 2. FIX: Enforce creator authorization for pending→joined transitions
-- ============================================================================
--
-- Only the plan creator may approve a pending request.
-- The requester must NOT be able to self-approve.

DROP TRIGGER IF EXISTS trg_enforce_plan_member_transitions ON public.plan_members;
DROP FUNCTION IF EXISTS public.enforce_plan_member_transitions();

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

  -- pending -> joined: ONLY the creator may approve
  IF OLD.status = 'pending' AND NEW.status = 'joined' THEN
    IF auth.uid() <> (
      SELECT creator_id FROM public.plans WHERE id = NEW.plan_id
    ) THEN
      RAISE EXCEPTION 'Only the plan creator can approve a pending membership';
    END IF;
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

  RAISE EXCEPTION 'Invalid plan member status transition: % → %', OLD.status, NEW.status;
END;
$$;

CREATE TRIGGER trg_enforce_plan_member_transitions
  BEFORE UPDATE ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_plan_member_transitions();

-- ============================================================================
-- 3. FIX: Private Plan visibility for creator's accepted Connections
-- ============================================================================
--
-- Private plans must be discoverable by:
--   * the creator
--   * the creator's accepted Connections
--   * existing joined members
--   * pending invitees
--
-- The existing creator/member/invitee policies already cover those cases.
-- This adds the missing accepted-connection policy.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Accepted connections can read private plans'
  ) THEN
    CREATE POLICY "Accepted connections can read private plans"
      ON public.plans FOR SELECT
      TO authenticated
      USING (
        visibility = 'private'
        AND EXISTS (
          SELECT 1 FROM public.connections
          WHERE (
            (connections.requester_id = plans.creator_id
             AND connections.recipient_id = auth.uid())
            OR
            (connections.recipient_id = plans.creator_id
             AND connections.requester_id = auth.uid())
          )
          AND connections.status = 'accepted'
        )
      );
  END IF;
END $$;

-- ============================================================================
-- 4. FIX: Atomic server-side capacity enforcement
-- ============================================================================
--
-- When a membership transitions to 'joined', atomically verify that the
-- plan has not reached capacity. The plan row is locked with SELECT ... FOR
-- UPDATE so concurrent approvals cannot both pass the capacity check.
--
-- The creator's automatic membership is inserted by a SECURITY DEFINER
-- trigger AFTER the plan is created, which runs before any approval can
-- occur, so it is counted correctly.

CREATE OR REPLACE FUNCTION public.enforce_plan_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity INTEGER;
  v_joined_count INTEGER;
BEGIN
  -- Only enforce when transitioning TO 'joined'
  IF TG_OP = 'INSERT' AND NEW.status = 'joined' THEN
    SELECT capacity INTO v_capacity
    FROM public.plans
    WHERE id = NEW.plan_id
    FOR UPDATE;

    IF v_capacity IS NULL THEN
      RAISE EXCEPTION 'Plan not found';
    END IF;

    SELECT COUNT(*) INTO v_joined_count
    FROM public.plan_members
    WHERE plan_id = NEW.plan_id
      AND status = 'joined';

    IF v_joined_count >= v_capacity THEN
      RAISE EXCEPTION 'Plan is full. Cannot add another member.';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.status = 'joined' AND OLD.status <> 'joined' THEN
    SELECT capacity INTO v_capacity
    FROM public.plans
    WHERE id = NEW.plan_id
    FOR UPDATE;

    IF v_capacity IS NULL THEN
      RAISE EXCEPTION 'Plan not found';
    END IF;

    SELECT COUNT(*) INTO v_joined_count
    FROM public.plan_members
    WHERE plan_id = NEW.plan_id
      AND status = 'joined';

    IF v_joined_count >= v_capacity THEN
      RAISE EXCEPTION 'Plan is full. Cannot approve another member.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_plan_capacity ON public.plan_members;

CREATE TRIGGER trg_enforce_plan_capacity
  BEFORE INSERT OR UPDATE ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_plan_capacity();
