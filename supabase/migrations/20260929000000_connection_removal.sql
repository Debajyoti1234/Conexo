-- Connection removal: add 'removed' status and allow accepted -> removed transition

-- 1. Extend status check constraint to include 'removed'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'connections_status_check'
      AND conrelid = 'connections'::regclass
  ) THEN
    ALTER TABLE public.connections
    DROP CONSTRAINT connections_status_check;
  END IF;
END $$;

ALTER TABLE public.connections
ADD CONSTRAINT connections_status_check
CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'removed'));

-- 2. Extend state-machine trigger to allow accepted -> removed (either participant)
CREATE OR REPLACE FUNCTION public.enforce_connection_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.requester_id <> OLD.requester_id THEN
    RAISE EXCEPTION 'requester_id is immutable';
  END IF;
  IF NEW.recipient_id <> OLD.recipient_id THEN
    RAISE EXCEPTION 'recipient_id is immutable';
  END IF;
  IF NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable';
  END IF;

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

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

  IF OLD.status = 'accepted' AND NEW.status = 'removed' THEN
    IF auth.uid() <> NEW.requester_id AND auth.uid() <> NEW.recipient_id THEN
      RAISE EXCEPTION 'Only participants can remove a connection';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid connection status transition: % → %', OLD.status, NEW.status;
END;
$$;
