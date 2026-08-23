-- P1.2B.16I: Plan Lifecycle — Archive / Restore / Delete
--
-- Additive only. Uses the existing plans.status column ('archived' already
-- exists in the CHECK constraint). No new tables, no Storage changes.
--
-- 1. Tighten get_or_create_plan_conversation:
--    Reject archived plans with a clear error instead of silently allowing chat.
--
-- 2. New atomic delete_plan RPC:
--    Removes the plan, its members/invites, and its chat room (conversation,
--    conversation_members, messages) in one SECURITY DEFINER call. Only the
--    creator may delete.

-- ============================================================================
-- 1. TIGHTEN PLAN CHAT ACCESS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_or_create_plan_conversation(
  p_plan_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := auth.uid();
  v_conversation_id uuid;
  v_is_creator boolean;
  v_is_joined boolean;
  v_plan_exists boolean;
  v_plan_status text;
BEGIN
  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.plans WHERE id = p_plan_id)
    INTO v_plan_exists;
  IF NOT v_plan_exists THEN
    RAISE EXCEPTION 'Plan not found';
  END IF;

  SELECT status INTO v_plan_status
  FROM public.plans
  WHERE id = p_plan_id;

  IF v_plan_status = 'archived' THEN
    RAISE EXCEPTION 'Chat temporarily revoked by host';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.plans
    WHERE id = p_plan_id AND creator_id = v_current_user
  ) INTO v_is_creator;

  SELECT EXISTS(
    SELECT 1 FROM public.plan_members
    WHERE plan_id = p_plan_id
      AND user_id = v_current_user
      AND status = 'joined'
  ) INTO v_is_joined;

  IF NOT v_is_creator AND NOT v_is_joined THEN
    RAISE EXCEPTION 'Not authorized to access this plan chat';
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE plan_id = p_plan_id AND type = 'plan'
  LIMIT 1;

  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations (type, plan_id)
    VALUES ('plan', p_plan_id)
    ON CONFLICT (plan_id) WHERE plan_id IS NOT NULL DO NOTHING
    RETURNING id INTO v_conversation_id;

    IF v_conversation_id IS NULL THEN
      SELECT id INTO v_conversation_id
      FROM public.conversations
      WHERE plan_id = p_plan_id AND type = 'plan'
      LIMIT 1;
    END IF;
  END IF;

  INSERT INTO public.conversation_members (conversation_id, user_id)
  SELECT v_conversation_id, pm.user_id
  FROM public.plan_members pm
  WHERE pm.plan_id = p_plan_id
    AND pm.status = 'joined'
  ON CONFLICT (conversation_id, user_id) DO NOTHING;

  RETURN v_conversation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_plan_conversation(uuid) TO authenticated;

-- ============================================================================
-- 2. ATOMIC PLAN DELETE
-- ============================================================================
--
-- Removes:
--   plan_members, plan_invites
--   conversation_members, messages, conversations (plan chat)
--   plans row
--
-- Only the creator may delete. Returns the deleted plan id on success.

CREATE OR REPLACE FUNCTION public.delete_plan(
  p_plan_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := auth.uid();
  v_conversation_id uuid;
BEGIN
  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.plans
    WHERE id = p_plan_id AND creator_id = v_current_user
  ) THEN
    RAISE EXCEPTION 'Not authorized to delete this plan';
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE plan_id = p_plan_id AND type = 'plan'
  LIMIT 1;

  IF v_conversation_id IS NOT NULL THEN
    DELETE FROM public.messages
    WHERE conversation_id = v_conversation_id;

    DELETE FROM public.conversation_members
    WHERE conversation_id = v_conversation_id;

    DELETE FROM public.conversations
    WHERE id = v_conversation_id;
  END IF;

  DELETE FROM public.plan_invites
  WHERE plan_id = p_plan_id;

  DELETE FROM public.plan_members
  WHERE plan_id = p_plan_id;

  DELETE FROM public.plans
  WHERE id = p_plan_id;

  RETURN p_plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_plan(uuid) TO authenticated;
