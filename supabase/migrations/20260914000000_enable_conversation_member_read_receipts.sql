-- Chat P4: enable sender-visible read receipts via conversation_members.
--
-- Background:
--   The canonical read position is conversation_members.last_read_at.
--   The sender must be able to read the recipient's row so the sender's UI
--   can derive "sent" vs "read" per message. Previously SELECT was limited
--   to auth.uid() = user_id, which blocked cross-user visibility entirely.
--
-- Approach:
--   Replace the direct RLS subquery with a SECURITY DEFINER helper that
--   returns true only when the caller is a member of the SAME conversation.
--   This is the same non-recursive pattern already used for plan_members
--   (see 20260829020000_fix_plan_rls_recursion.sql / is_plan_member).
--   It does NOT widen access to unrelated conversations.

-- ============================================================================
-- 1. SECURITY DEFINER HELPER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_conversation_member(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.conversation_members
    WHERE conversation_id = p_conversation_id
      AND user_id = auth.uid()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_conversation_member(UUID) TO authenticated;

-- ============================================================================
-- 2. REPLACE SELECT POLICY
-- ============================================================================

DROP POLICY IF EXISTS "Members can read membership" ON public.conversation_members;

CREATE POLICY "Members can read membership"
  ON public.conversation_members
  FOR SELECT
  TO authenticated
  USING (public.is_conversation_member(conversation_members.conversation_id));

-- UPDATE / INSERT / DELETE policies are intentionally unchanged:
--   "Users can update own membership"   (auth.uid() = user_id)
--   "Users can insert themselves"       (auth.uid() = user_id)
--   "Users can remove themselves"       (auth.uid() = user_id)
-- A user can therefore only mutate their own row; the widened SELECT only
-- exposes co-members' last_read_at / last_notified_at for read-receipt UI.

-- ============================================================================
-- 3. REALTIME: FULL REPLICA IDENTITY
-- ============================================================================
--
-- Read receipts rely on the SENDER receiving a realtime UPDATE when the
-- RECIPIENT advances their last_read_at. Supabase Realtime enforces RLS on
-- postgres_changes; for UPDATE/DELETE it needs the full row (not just the
-- primary key) to authorize the change against the SELECT policy above.
-- Without REPLICA IDENTITY FULL the pre-image only carries the PK, so the
-- membership check (is_conversation_member(conversation_id)) can fail and the
-- event is silently dropped for the sender. FULL makes the whole row available
-- so the co-member SELECT policy authorizes delivery. conversation_members is
-- small and updated infrequently (last_read_at), so the WAL overhead is
-- negligible. The table is already in the supabase_realtime publication
-- (20260821000000_create_chat_foundation.sql).
ALTER TABLE public.conversation_members REPLICA IDENTITY FULL;
