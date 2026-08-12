-- Phase 9.4.6.3: Fix connections UPDATE RLS WITH CHECK semantics
--
-- The previous hardening migration used WITH CHECK (status = 'pending') for
-- both requester and recipient UPDATE policies. That is wrong for PostgreSQL
-- RLS: USING authorizes the EXISTING row, while WITH CHECK validates the NEW
-- row. Accept/reject/cancel all change status away from 'pending', so the
-- previous WITH CHECK rejected every legitimate state transition.

-- 1. Drop the broken UPDATE policies
DROP POLICY IF EXISTS "Requester can cancel own pending request" ON public.connections;
DROP POLICY IF EXISTS "Recipient can accept/reject pending requests" ON public.connections;

-- 2. Recreate requester UPDATE policy with correct semantics
-- USING: the existing row must belong to the requester and be pending
-- WITH CHECK: the new row must still belong to the requester and be cancelled
CREATE POLICY "Requester can cancel own pending request"
  ON public.connections
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = requester_id AND status = 'pending')
  WITH CHECK (auth.uid() = requester_id AND status = 'cancelled');

-- 3. Recreate recipient UPDATE policy with correct semantics
-- USING: the existing row must belong to the recipient and be pending
-- WITH CHECK: the new row must still belong to the recipient and be accepted or rejected
CREATE POLICY "Recipient can accept/reject pending requests"
  ON public.connections
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = recipient_id AND status = 'pending')
  WITH CHECK (auth.uid() = recipient_id AND status IN ('accepted', 'rejected'));
