-- P1.2B.8.5: Fix plan_members transition trigger (remove invalid created_at guard)
--
-- ROOT CAUSE (confirmed by live audit):
--   public.plan_members has timestamp columns joined_at + updated_at and does
--   NOT have a created_at column. However, enforce_plan_member_transitions()
--   contained an immutability guard referencing NEW.created_at / OLD.created_at
--   (copy-pasted from enforce_plan_invite_transitions(), whose table DOES have
--   created_at). PL/pgSQL resolves NEW/OLD record fields at runtime, so the
--   function was created successfully, but every UPDATE on plan_members that
--   fired this BEFORE UPDATE trigger failed with:
--       SQLSTATE 42703 - record "new" has no field "created_at"
--   This broke approve_plan_member, decline_plan_member, and remove_plan_member
--   (all perform an UPDATE on plan_members).
--
-- FIX:
--   CREATE OR REPLACE the function with the exact same body, removing ONLY the
--   invalid created_at immutability block. The valid joined_at immutability
--   guard is retained, and every other rule (authorization, creator-only
--   approve/decline/remove, pending->joined, pending->declined, joined->left,
--   joined->removed, status transition validation, all exception messages,
--   SECURITY DEFINER, search_path) is preserved verbatim.
--
-- SCOPE: additive/corrective only. No schema change to plan_members, no RLS
--   change, no RPC signature change, no change to plan_invites or
--   enforce_plan_invite_transitions().

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
