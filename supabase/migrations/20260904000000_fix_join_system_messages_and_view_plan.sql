-- P1.2B.9B: Fix join system messages + View Plan for joined members + Host profile
--
-- ADDITIVE / CORRECTIVE ONLY.
--
-- Changes:
--   1. sync_plan_conversation_members: use NEW.joined_at for message timestamp
--      (was using now() which could diverge from the authoritative joined_at).
--   2. get_or_create_plan_conversation: insert retroactive join system messages
--      for members who transitioned to joined before the conversation existed.
--      NOT EXISTS guard prevents duplicates for members whose join event was
--      already captured by the trigger.

-- ============================================================================
-- 1. FIX JOIN MESSAGE TIMESTAMP IN sync_plan_conversation_members
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_plan_conversation_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation_id uuid;
  v_plan_title text;
  v_user_name text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE plan_id = NEW.plan_id AND type = 'plan'
  LIMIT 1;

  IF v_conversation_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'joined' THEN
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_conversation_id, NEW.user_id)
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    SELECT p.title INTO v_plan_title
    FROM public.plans p
    WHERE p.id = NEW.plan_id;

    SELECT COALESCE(pr.display_name, split_part(NEW.user_id::text, '-', 1)) INTO v_user_name
    FROM public.profiles pr
    WHERE pr.id = NEW.user_id;

    IF v_plan_title IS NOT NULL THEN
      INSERT INTO public.messages (
        conversation_id,
        sender_id,
        type,
        content,
        created_at
      ) VALUES (
        v_conversation_id,
        NEW.user_id,
        'system',
        format('%s has joined the plan "%s"', v_user_name, v_plan_title),
        NEW.joined_at
      );
    END IF;
  ELSE
    DELETE FROM public.conversation_members
    WHERE conversation_id = v_conversation_id
      AND user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_plan_conversation_members ON public.plan_members;
CREATE TRIGGER trg_sync_plan_conversation_members
  AFTER UPDATE OF status ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_plan_conversation_members();

-- ============================================================================
-- 2. RETROACTIVE JOIN MESSAGES IN get_or_create_plan_conversation
-- ============================================================================
-- When a membership transitions pending -> joined before any Plan conversation
-- exists, the trigger above skips the system message because v_conversation_id
-- is NULL. The first user to open Group Chat calls get_or_create_plan_conversation,
-- which creates the conversation and seeds conversation_members. We extend it
-- here to also insert missed join system messages for all joined non-creator
-- members. The NOT EXISTS guard prevents duplicates for members whose join
-- event was already captured by the trigger.

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
BEGIN
  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.plans WHERE id = p_plan_id)
    INTO v_plan_exists;
  IF NOT v_plan_exists THEN
    RAISE EXCEPTION 'Plan not found';
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

  INSERT INTO public.messages (
    conversation_id,
    sender_id,
    type,
    content,
    created_at
  )
  SELECT
    v_conversation_id,
    pm.user_id,
    'system',
    format('%s has joined the plan "%s"', COALESCE(pr.display_name, split_part(pm.user_id::text, '-', 1)), p.title),
    pm.joined_at
  FROM public.plan_members pm
  JOIN public.plans p ON p.id = pm.plan_id
  LEFT JOIN public.profiles pr ON pr.id = pm.user_id
  WHERE pm.plan_id = p_plan_id
    AND pm.status = 'joined'
    AND pm.role != 'creator'
    AND NOT EXISTS (
      SELECT 1 FROM public.messages m
      WHERE m.conversation_id = v_conversation_id
        AND m.sender_id = pm.user_id
        AND m.type = 'system'
    );

  RETURN v_conversation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_plan_conversation(uuid) TO authenticated;
