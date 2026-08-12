-- Phase 9.5.1: Production Chat Database Foundation & RLS
-- Creates conversations, conversation_members, and messages tables
-- with production-safe RLS policies and indexes.

-- ============================================================================
-- 1. CONVERSATIONS
-- ============================================================================

CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('connection', 'plan')),
  plan_id UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_conversations_type
  ON public.conversations(type);

CREATE INDEX idx_conversations_plan_id
  ON public.conversations(plan_id)
  WHERE plan_id IS NOT NULL;

-- ============================================================================
-- 2. CONVERSATION MEMBERS
-- ============================================================================

CREATE TABLE public.conversation_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL
    REFERENCES public.conversations(id)
    ON DELETE CASCADE,
  user_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

CREATE INDEX idx_conversation_members_conversation_id
  ON public.conversation_members(conversation_id);

CREATE INDEX idx_conversation_members_user_id
  ON public.conversation_members(user_id);

-- ============================================================================
-- 3. MESSAGES
-- ============================================================================

CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL
    REFERENCES public.conversations(id)
    ON DELETE CASCADE,
  sender_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'text'
    CHECK (type IN ('text', 'voice', 'image', 'call_event', 'system')),
  content TEXT NOT NULL DEFAULT '',
  media_url TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_messages_conversation_id
  ON public.messages(conversation_id);

CREATE INDEX idx_messages_conversation_created_at
  ON public.messages(conversation_id, created_at DESC);

CREATE INDEX idx_messages_sender_id
  ON public.messages(sender_id);

CREATE INDEX idx_messages_deleted_at
  ON public.messages(deleted_at)
  WHERE deleted_at IS NULL;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CONVERSATIONS RLS
-- ============================================================================

-- Conversations are immutable from the client in this phase.
-- No INSERT, UPDATE, or DELETE policies.
-- SELECT is restricted to members only.
CREATE POLICY "Members can read conversations"
  ON public.conversations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = conversations.id
        AND cm.user_id = auth.uid()
    )
  );

-- ============================================================================
-- 6. CONVERSATION MEMBERS RLS
-- ============================================================================

CREATE POLICY "Members can read membership"
  ON public.conversation_members
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert themselves"
  ON public.conversation_members
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own membership"
  ON public.conversation_members
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove themselves"
  ON public.conversation_members
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================================
-- 7. MESSAGES RLS
-- ============================================================================

CREATE POLICY "Members can read messages"
  ON public.messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
        AND cm.user_id = auth.uid()
    )
  );

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
  );

CREATE POLICY "Senders can update own messages"
  ON public.messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

-- No DELETE policy. Messages use soft deletion via deleted_at.

-- ============================================================================
-- 8. REALTIME PUBLICATION
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
