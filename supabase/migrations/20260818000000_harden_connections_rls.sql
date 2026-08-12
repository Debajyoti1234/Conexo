-- Phase 9.4.6: Harden connections RLS
-- Replace the broad UPDATE policy with narrowly scoped policies + trigger enforcement

-- 1. Drop the broad update policy
DROP POLICY IF EXISTS "Users can update own connections" ON public.connections;

-- 2. Narrow requester-side UPDATE policy: can only cancel their own pending requests
CREATE POLICY "Requester can cancel own pending request"
  ON public.connections
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = requester_id AND status = 'pending')
  WITH CHECK (auth.uid() = requester_id AND status = 'pending');

-- 3. Narrow recipient-side UPDATE policy: can accept/reject incoming pending requests
CREATE POLICY "Recipient can accept/reject pending requests"
  ON public.connections
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = recipient_id AND status = 'pending')
  WITH CHECK (auth.uid() = recipient_id AND status = 'pending');

-- 4. Trigger function: enforce allowed state transitions and immutability
CREATE OR REPLACE FUNCTION public.enforce_connection_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Enforce immutability of identity and creation timestamp
  IF NEW.requester_id <> OLD.requester_id THEN
    RAISE EXCEPTION 'requester_id is immutable';
  END IF;
  IF NEW.recipient_id <> OLD.recipient_id THEN
    RAISE EXCEPTION 'recipient_id is immutable';
  END IF;
  IF NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable';
  END IF;

  -- No transition needed if status unchanged
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Allowed transitions
  IF OLD.status = 'pending' AND NEW.status = 'cancelled' THEN
    IF auth.uid() <> NEW.requester_id THEN
      RAISE EXCEPTION 'Only requester can cancel a pending request';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    IF auth.uid() <> NEW.recipient_id THEN
      RAISE EXCEPTION 'Only recipient can accept a pending request';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'rejected' THEN
    IF auth.uid() <> NEW.recipient_id THEN
      RAISE EXCEPTION 'Only recipient can reject a pending request';
    END IF;
    RETURN NEW;
  END IF;

  -- All other transitions are forbidden
  RAISE EXCEPTION 'Invalid connection status transition: % → %', OLD.status, NEW.status;
END;
$$;

-- 5. Attach trigger to connections table
DROP TRIGGER IF EXISTS trg_enforce_connection_transitions ON public.connections;
CREATE TRIGGER trg_enforce_connection_transitions
  BEFORE UPDATE ON public.connections
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_connection_transitions();
