-- Phase 9.5.2: Message Likes
-- Adds message_likes table, RLS, and helper RPCs for per-user likes.

-- ============================================================================
-- 1. MESSAGE LIKES TABLE
-- ============================================================================

CREATE TABLE public.message_likes (
  message_id UUID NOT NULL
    REFERENCES public.messages(id)
    ON DELETE CASCADE,
  user_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX idx_message_likes_message_id
  ON public.message_likes(message_id);

CREATE INDEX idx_message_likes_user_id
  ON public.message_likes(user_id);

-- ============================================================================
-- 2. ENABLE RLS
-- ============================================================================

ALTER TABLE public.message_likes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. MESSAGE LIKES RLS
-- ============================================================================

CREATE POLICY "Members can read likes"
  ON public.message_likes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = (
            SELECT conversation_id FROM public.messages WHERE id = message_likes.message_id
          )
        AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "Members can insert likes"
  ON public.message_likes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = (
            SELECT conversation_id FROM public.messages WHERE id = message_likes.message_id
          )
        AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "Members can delete own likes"
  ON public.message_likes
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = (
            SELECT conversation_id FROM public.messages WHERE id = message_likes.message_id
          )
        AND cm.user_id = auth.uid()
    )
  );

-- ============================================================================
-- 4. REALTIME PUBLICATION
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.message_likes;
