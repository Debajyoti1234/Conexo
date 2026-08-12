-- Phase 9.4.5: Production Connection Backend

-- 1. Create connections table
CREATE TABLE IF NOT EXISTS public.connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Constrain status to known values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'connections_status_check'
      AND conrelid = 'connections'::regclass
  ) THEN
    ALTER TABLE public.connections
    ADD CONSTRAINT connections_status_check
    CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled'));
  END IF;
END $$;

-- 3. Prevent self-connections
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'connections_no_self'
      AND conrelid = 'connections'::regclass
  ) THEN
    ALTER TABLE public.connections
    ADD CONSTRAINT connections_no_self
    CHECK (requester_id != recipient_id);
  END IF;
END $$;

-- 4. Prevent duplicate active requests between the same two users
--    (regardless of direction) for pending/accepted states.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_connections_unique_pair'
  ) THEN
    CREATE UNIQUE INDEX idx_connections_unique_pair
      ON public.connections (LEAST(requester_id, recipient_id), GREATEST(requester_id, recipient_id))
      WHERE status IN ('pending', 'accepted');
  END IF;
END $$;

-- 5. Index for recipient's incoming requests
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_connections_recipient'
  ) THEN
    CREATE INDEX idx_connections_recipient
      ON public.connections(recipient_id, status);
  END IF;
END $$;

-- 6. Index for requester's outgoing requests
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_connections_requester'
  ) THEN
    CREATE INDEX idx_connections_requester
      ON public.connections(requester_id, status);
  END IF;
END $$;

-- 7. Enable RLS
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

-- 8. RLS: Users can view connections involving themselves
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'connections'
      AND policyname = 'Users can view own connections'
  ) THEN
    CREATE POLICY "Users can view own connections"
      ON public.connections FOR SELECT
      USING (auth.uid() = requester_id OR auth.uid() = recipient_id);
  END IF;
END $$;

-- 9. RLS: Users can insert requests where they are the requester
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'connections'
      AND policyname = 'Users can send connection requests'
  ) THEN
    CREATE POLICY "Users can send connection requests"
      ON public.connections FOR INSERT
      WITH CHECK (auth.uid() = requester_id);
  END IF;
END $$;

-- 10. RLS: Users can update only records they are involved in
--     (requester can cancel, recipient can accept/reject)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'connections'
      AND policyname = 'Users can update own connections'
  ) THEN
    CREATE POLICY "Users can update own connections"
      ON public.connections FOR UPDATE
      USING (auth.uid() = requester_id OR auth.uid() = recipient_id);
  END IF;
END $$;

-- 11. RLS: Users can delete only their own requests (requester cancels)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'connections'
      AND policyname = 'Users can delete own requests'
  ) THEN
    CREATE POLICY "Users can delete own requests"
      ON public.connections FOR DELETE
      USING (auth.uid() = requester_id);
  END IF;
END $$;
