-- P1.2B.14: Plan visits persistence for Recently Visited Discovery section
--
-- Adds a lightweight plan_visits table and SECURITY DEFINER helpers so the
-- client can record and retrieve a user's recently visited plans without
-- exposing unauthorized plans. RLS on plans remains the authoritative gate.

-- ============================================================================
-- 1. TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.plan_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,
  plan_id UUID NOT NULL
    REFERENCES public.plans(id)
    ON DELETE CASCADE,
  visited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, plan_id)
);

CREATE INDEX IF NOT EXISTS idx_plan_visits_user_id_visited_at
  ON public.plan_visits(user_id, visited_at DESC);

-- ============================================================================
-- 2. RLS
-- ============================================================================

ALTER TABLE public.plan_visits ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_visits'
      AND policyname = 'Users can read own visits'
  ) THEN
    CREATE POLICY "Users can read own visits"
      ON public.plan_visits FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_visits'
      AND policyname = 'Users can insert own visits'
  ) THEN
    CREATE POLICY "Users can insert own visits"
      ON public.plan_visits FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_visits'
      AND policyname = 'Users can update own visits'
  ) THEN
    CREATE POLICY "Users can update own visits"
      ON public.plan_visits FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_visits'
      AND policyname = 'Users can delete own visits'
  ) THEN
    CREATE POLICY "Users can delete own visits"
      ON public.plan_visits FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- 3. RPCs
-- ============================================================================

-- Records (or refreshes) a plan visit for the current user.
CREATE OR REPLACE FUNCTION public.record_plan_visit(p_plan_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.plan_visits (user_id, plan_id, visited_at)
  VALUES (auth.uid(), p_plan_id, now())
  ON CONFLICT (user_id, plan_id) DO UPDATE
    SET visited_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_plan_visit(UUID) TO authenticated;

-- Returns the current user's recently visited plan ids, most recent first.
CREATE OR REPLACE FUNCTION public.get_recently_visited_plan_ids(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(plan_id UUID, visited_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT v.plan_id, v.visited_at
  FROM public.plan_visits v
  WHERE v.user_id = auth.uid()
  ORDER BY v.visited_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_recently_visited_plan_ids(INTEGER) TO authenticated;
