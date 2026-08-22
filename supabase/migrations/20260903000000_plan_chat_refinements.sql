-- P1.2B.9A: Plan Chat Member Management & Navigation Refinement
--
-- ADDITIVE ONLY. Reuses existing RPCs, triggers, and RLS. Does not modify
-- Connection Chat, Plan discovery, Plan membership state machine, or
-- profile-photo privacy.
--
-- Changes:
--   1. Extend sync_plan_conversation_members() to insert a 'system' message
--      when a member transitions pending -> joined.
--   2. Add a trigger to bump conversations.updated_at on new messages so
--      Plan rooms sort by latest activity.

-- ============================================================================
-- 1. JOIN SYSTEM MESSAGE
-- ============================================================================
-- When a membership transitions to 'joined', the existing
-- sync_plan_conversation_members() trigger already adds the user to
-- conversation_members. We extend it to also emit a system message so
-- existing participants see the join event in realtime.
--
-- Idempotency: the trigger fires AFTER UPDATE OF status, and the inner
-- function returns early when NEW.status = OLD.status. A membership row
-- can only transition pending -> joined once, so exactly one system message
-- is produced per join.
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
        now()
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

-- Re-attach trigger (DROP + CREATE to survive function replacement).
DROP TRIGGER IF EXISTS trg_sync_plan_conversation_members ON public.plan_members;
CREATE TRIGGER trg_sync_plan_conversation_members
  AFTER UPDATE OF status ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_plan_conversation_members();

-- ============================================================================
-- 2. BUMP CONVERSATION ACTIVITY ON NEW MESSAGES
-- ============================================================================
-- conversations.updated_at is the activity timestamp used to sort Plan rooms
-- in the Chat -> Plans inbox. This trigger bumps it on every new message
-- (including system messages), so a member joining naturally moves the room
-- to the top.
CREATE OR REPLACE FUNCTION public.bump_conversation_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.conversations
  SET updated_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bump_conversation_updated_at ON public.messages;
CREATE TRIGGER trg_bump_conversation_updated_at
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.bump_conversation_updated_at();
