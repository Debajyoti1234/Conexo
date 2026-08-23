-- Chat P3: server-side block enforcement + bidirectional block helper.
--
-- Aligns enforcement with the canonical LIVE schema:
--   * Block relationship lives in public.blocks (blocker_id, blocked_id).
--   * Per-user conversation mute lives in public.conversation_mutes
--     (conversation_id, user_id, muted_at) — created by an earlier migration.
--
-- This migration is additive and idempotent and creates NO new tables. It does
-- NOT add conversation_members.muted_at (mute is stored in conversation_mutes,
-- the single source of truth).

-- ============================================================================
-- 1. SERVER-SIDE BLOCK ENFORCEMENT FOR CONNECTION MESSAGES
-- ============================================================================
--
-- Replaces the existing "Members can insert messages" policy. The new policy
-- keeps the original membership rule and additionally rejects inserts into a
-- 'connection' conversation when a block exists in EITHER direction between
-- the sender and the other member. Plan ('plan') conversations keep the
-- original behavior untouched.

DROP POLICY IF EXISTS "Members can insert messages" ON public.messages;

CREATE POLICY "Members can insert messages"
  ON public.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
        AND cm.user_id = auth.uid()
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.conversations c
      JOIN public.conversation_members other
        ON other.conversation_id = c.id
       AND other.user_id <> auth.uid()
      JOIN public.blocks bl
        ON (bl.blocker_id = auth.uid() AND bl.blocked_id = other.user_id)
        OR (bl.blocker_id = other.user_id AND bl.blocked_id = auth.uid())
      WHERE c.id = messages.conversation_id
        AND c.type = 'connection'
    )
  );

-- ============================================================================
-- 2. BIDIRECTIONAL BLOCK HELPER FOR DISCOVERY FILTERING
-- ============================================================================
--
-- RLS on public.blocks only exposes rows where the caller is the blocker, so a
-- client cannot see "who blocked me". Discovery must hide users in BOTH
-- directions. This SECURITY DEFINER function returns only the set of user ids
-- relevant to the caller (people the caller blocked + people who blocked the
-- caller) without exposing any other block relationships or metadata.

CREATE OR REPLACE FUNCTION public.blocked_profile_ids()
RETURNS TABLE (user_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT blocked_id AS user_id
  FROM public.blocks
  WHERE blocker_id = auth.uid()
  UNION
  SELECT blocker_id AS user_id
  FROM public.blocks
  WHERE blocked_id = auth.uid()
$$;

REVOKE ALL ON FUNCTION public.blocked_profile_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.blocked_profile_ids() TO authenticated;
