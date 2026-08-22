-- Phase 9.5.3: Add last_notified_at for notification deduplication
ALTER TABLE public.conversation_members
  ADD COLUMN IF NOT EXISTS last_notified_at TIMESTAMPTZ NULL;

CREATE INDEX idx_conversation_members_last_notified_at
  ON public.conversation_members(conversation_id, last_notified_at)
  WHERE last_notified_at IS NOT NULL;
