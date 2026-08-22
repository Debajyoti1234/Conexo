-- P1.2B.9: Plan Group Chat Integration
--
-- Connects the existing Plan system (plans, plan_members) to the existing real
-- Chat architecture (conversations, conversation_members, messages).
--
-- ADDITIVE / CORRECTIVE ONLY. This migration does NOT change:
--   * Connection chat (get_or_create_connection_conversation, its RLS)
--   * The Plan membership state machine (enforce_plan_member_transitions)
--   * Plan discovery / visibility / plans RLS
--   * Storage buckets or their policies
--
-- CANONICAL MODEL:
--   One Plan  =>  at most ONE conversation (type = 'plan', plan_id = plans.id)
--   Chat members mirror plan_members WHERE status = 'joined'.
--   Conversations are created LAZILY by get_or_create_plan_conversation();
--   publishing a Plan does NOT create an empty conversation.
--
-- SECURITY:
--   Chat access requires a conversation_members row. That row is only ever
--   created for the creator + joined members. Pending/declined/left/removed
--   users are never added, and are removed on transition away from 'joined'.
--   The client cannot manufacture conversations: conversations has no client
--   INSERT policy, so creation flows exclusively through the SECURITY DEFINER
--   RPC below, which authorizes creator-or-joined before creating anything.

-- ============================================================================
-- 0. SAFETY: refuse to proceed if duplicate plan conversations already exist
-- ============================================================================
-- The Plan chat feature was never wired before this migration, so no
-- type = 'plan' conversation should exist yet. If duplicates somehow exist,
-- STOP (never silently merge/delete chat data) so they can be inspected.
DO $$
DECLARE
  v_dupe_count integer;
BEGIN
  SELECT count(*) INTO v_dupe_count
  FROM (
    SELECT plan_id
    FROM public.conversations
    WHERE plan_id IS NOT NULL
    GROUP BY plan_id
    HAVING count(*) > 1
  ) d;

  IF v_dupe_count > 0 THEN
    RAISE EXCEPTION
      'Aborting P1.2B.9: % plan_id value(s) have duplicate conversations. '
      'Resolve duplicates manually before creating the unique index.',
      v_dupe_count;
  END IF;
END $$;

-- ============================================================================
-- 1. ONE PLAN = ONE CONVERSATION
-- ============================================================================
-- Guarantees a single conversation per Plan. Connection conversations have
-- plan_id = NULL and are unaffected by this partial unique index.
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_plan_id_unique
  ON public.conversations(plan_id)
  WHERE plan_id IS NOT NULL;

-- ============================================================================
-- 2. get_or_create_plan_conversation
-- ============================================================================
-- Lazily finds or creates the single conversation for a Plan and seeds its
-- members from the current joined plan_members. Idempotent: repeated calls
-- always return the same conversation id.
--
-- Authorization: caller must be the Plan creator OR a joined member.
-- Pending / declined / left / removed callers are rejected.
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

  -- Reuse an existing plan conversation if present.
  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE plan_id = p_plan_id AND type = 'plan'
  LIMIT 1;

  -- Create it lazily. The unique index makes this safe under concurrency:
  -- a losing concurrent insert falls through to the re-select below.
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

  -- Seed / reconcile chat membership from the current joined plan members
  -- (this includes the creator, who is a role='creator' status='joined' row).
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
-- 3. plan_members  ->  conversation_members  SYNCHRONIZATION
-- ============================================================================
-- Keeps chat membership aligned with Plan membership WHEN a conversation
-- already exists. Never creates a conversation (lazy-creation model).
--
--   pending  -> joined   : add to conversation_members
--   joined   -> left      : remove from conversation_members
--   joined   -> removed   : remove from conversation_members
--   pending  -> declined  : no-op (was never a chat member)
--   any -> non-joined     : ensure not a chat member
--
-- SECURITY DEFINER so it can reconcile conversation_members regardless of the
-- acting client's RLS. It only touches conversations + conversation_members
-- (never plan_members), so there is no RLS recursion.
CREATE OR REPLACE FUNCTION public.sync_plan_conversation_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation_id uuid;
BEGIN
  -- Only react to a real status change.
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_conversation_id
  FROM public.conversations
  WHERE plan_id = NEW.plan_id AND type = 'plan'
  LIMIT 1;

  -- No conversation yet => nothing to sync. The first eligible user opening
  -- Group Chat will create it and seed all current joined members.
  IF v_conversation_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'joined' THEN
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_conversation_id, NEW.user_id)
    ON CONFLICT (conversation_id, user_id) DO NOTHING;
  ELSE
    DELETE FROM public.conversation_members
    WHERE conversation_id = v_conversation_id
      AND user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Fires only when an UPDATE touches the status column. It runs AFTER the
-- existing BEFORE UPDATE enforce_plan_member_transitions trigger has validated
-- and applied the transition, so it never interferes with that state machine.
DROP TRIGGER IF EXISTS trg_sync_plan_conversation_members ON public.plan_members;
CREATE TRIGGER trg_sync_plan_conversation_members
  AFTER UPDATE OF status ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_plan_conversation_members();
