-- ============================================================================
-- Plan Discovery: private-plan visibility for accepted connections
-- ============================================================================
--
-- The canonical private-plan rule is:
--   • creator
--   + creator's accepted connections
--   + joined members
--   + pending invitees
--
-- The existing RLS already covers creator / joined / invitee.
-- This migration adds the missing accepted-connection eligibility using the
-- same additive, idempotent pattern as the foundation migration.

-- 1. SECURITY DEFINER helper: accepted connection IDs for a user.
--    Mirrors the existing blocked_profile_ids() shape.
CREATE OR REPLACE FUNCTION public.accepted_connection_ids(p_user_id UUID)
RETURNS TABLE(user_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN requester_id = p_user_id THEN recipient_id
      ELSE requester_id
    END AS user_id
  FROM public.connections
  WHERE status = 'accepted'
    AND (requester_id = p_user_id OR recipient_id = p_user_id);
$$;

-- 2. New RLS policy: accepted connections can read private active plans
--    created by their accepted connections.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Connections can read private plans of accepted connections'
  ) THEN
    CREATE POLICY "Connections can read private plans of accepted connections"
      ON public.plans FOR SELECT
      TO authenticated
      USING (
        visibility = 'private'
        AND status = 'active'
        AND EXISTS (
          SELECT 1
          FROM public.connections c
          WHERE c.status = 'accepted'
            AND (
              (c.requester_id = auth.uid() AND c.recipient_id = plans.creator_id)
              OR (c.recipient_id = auth.uid() AND c.requester_id = plans.creator_id)
            )
        )
      );
  END IF;
END $$;
