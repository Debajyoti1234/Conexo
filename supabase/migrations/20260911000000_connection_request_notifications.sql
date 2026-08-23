-- Chat P1: Connection request notification trigger
--
-- Creates a server-side notification when a new pending connection request
-- is inserted into the connections table. Uses SECURITY DEFINER so the
-- trigger can insert notifications on behalf of the recipient regardless
-- of the requester's RLS permissions.

CREATE OR REPLACE FUNCTION public.create_connection_request_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(display_name, split_part(requester_id::text, '-', 1))
      INTO v_requester_name
      FROM public.profiles
      WHERE id = NEW.requester_id;

    INSERT INTO public.notifications (
      user_id,
      actor_id,
      kind,
      title,
      body,
      entity_id,
      entity_type,
      read,
      created_at
    ) VALUES (
      NEW.recipient_id,
      NEW.requester_id,
      'request',
      'New connection request',
      format('"%s" wants to connect with you.', COALESCE(v_requester_name, 'Someone')),
      NEW.id,
      'connection_request',
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_connection_request_notification ON public.connections;
CREATE TRIGGER trg_create_connection_request_notification
  AFTER INSERT ON public.connections
  FOR EACH ROW
  EXECUTE FUNCTION public.create_connection_request_notification();
