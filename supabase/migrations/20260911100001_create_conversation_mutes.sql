-- Phase 9.5.3: Conversation mutes (prerequisite migration)
-- Created to satisfy migration ordering for fresh environments.
-- The canonical remote table already exists; this migration ensures
-- a fresh supabase db push can recreate it before dependent migrations run.
CREATE TABLE IF NOT EXISTS public.conversation_mutes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  muted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conversation_mutes_user_id ON public.conversation_mutes(user_id);
CREATE INDEX IF NOT EXISTS idx_conversation_mutes_conversation_id ON public.conversation_mutes(conversation_id);

ALTER TABLE public.conversation_mutes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own mutes" ON public.conversation_mutes;
CREATE POLICY "Users can read own mutes"
  ON public.conversation_mutes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own mute" ON public.conversation_mutes;
CREATE POLICY "Users can insert own mute"
  ON public.conversation_mutes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own mute" ON public.conversation_mutes;
CREATE POLICY "Users can update own mute"
  ON public.conversation_mutes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own mute" ON public.conversation_mutes;
CREATE POLICY "Users can delete own mute"
  ON public.conversation_mutes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
