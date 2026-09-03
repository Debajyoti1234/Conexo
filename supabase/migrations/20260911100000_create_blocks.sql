-- Phase 9.5.3: Blocks (prerequisite migration)
-- Created to satisfy migration ordering for fresh environments.
-- The canonical remote table already exists; this migration ensures
-- a fresh supabase db push can recreate it before dependent migrations run.
CREATE TABLE IF NOT EXISTS public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker_id ON public.blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_id ON public.blocks(blocked_id);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own blocks" ON public.blocks;
CREATE POLICY "Users can read own blocks"
  ON public.blocks
  FOR SELECT
  TO authenticated
  USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can insert own block" ON public.blocks;
CREATE POLICY "Users can insert own block"
  ON public.blocks
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = blocker_id AND blocker_id <> blocked_id);

DROP POLICY IF EXISTS "Users can delete own block" ON public.blocks;
CREATE POLICY "Users can delete own block"
  ON public.blocks
  FOR DELETE
  TO authenticated
  USING (auth.uid() = blocker_id);
