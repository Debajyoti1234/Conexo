-- P1.2B.8.4: Creator removal of a joined participant
--
-- Adds a SECURITY DEFINER RPC:
--   * remove_plan_member - creator removes a joined member (joined -> removed)
--
-- WHY THIS MIGRATION IS REQUIRED (inspection result):
--   * The existing enforce_plan_member_transitions trigger ALREADY authorizes
--     the 'joined' -> 'removed' transition, but ONLY when auth.uid() equals the
--     plan creator (see 20260829010000_fix_plans_membership_security.sql).
--   * However, plan_members RLS only exposes an UPDATE policy
--     "Users can update own membership" (auth.uid() = user_id). There is NO
--     creator UPDATE policy, so a creator CANNOT update another member's row
--     directly from the client — RLS rejects it before the trigger runs.
--   * This is the identical constraint already solved for approve/decline via
--     SECURITY DEFINER RPCs (20260830000000_create_plan_approval_rpc.sql).
--     There is no existing removal RPC and no safe client path, so a matching
--     SECURITY DEFINER RPC is the smallest correct addition. It reuses the
--     existing trigger authorization and does NOT add any duplicate RLS policy.
--
-- Capacity: capacity is counted as status = 'joined', so setting a member to
-- 'removed' frees a spot automatically under the existing capacity model.

CREATE OR REPLACE FUNCTION public.remove_plan_member(p_plan_id UUID, p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Authorization: only the plan creator may remove a participant.
  IF auth.uid() <> (
    SELECT creator_id FROM public.plans WHERE id = p_plan_id
  ) THEN
    RAISE EXCEPTION 'Only the plan creator can remove members';
  END IF;

  -- The creator can never remove themselves via this path.
  IF p_user_id = (
    SELECT creator_id FROM public.plans WHERE id = p_plan_id
  ) THEN
    RAISE EXCEPTION 'The creator cannot be removed from their own plan';
  END IF;

  -- Only a currently joined member can be removed. The existing
  -- enforce_plan_member_transitions trigger validates joined -> removed.
  UPDATE public.plan_members
  SET status = 'removed', updated_at = now()
  WHERE plan_id = p_plan_id
    AND user_id = p_user_id
    AND status = 'joined';
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_plan_member(UUID, UUID) TO authenticated;
