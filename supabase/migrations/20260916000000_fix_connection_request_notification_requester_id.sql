-- Regression fix: connection request creation failed with
-- `column "requester_id" does not exist`.
--
-- Root cause: create_connection_request_notification() (added in
-- 20260911000000_connection_request_notifications.sql) referenced an
-- UNQUALIFIED `requester_id` inside `SELECT ... FROM public.profiles`. Postgres
-- resolves an unqualified identifier there against the FROM table (profiles),
-- which has no `requester_id` column, so the AFTER INSERT trigger on
-- public.connections raised 42703 and rolled back every connection request
-- (the "Connect" action from People).
--
-- Fix: qualify the fallback name source as NEW.requester_id (the connection
-- row's requester), matching the WHERE clause that already uses
-- NEW.requester_id. This corrects the EXISTING function in place via
-- CREATE OR REPLACE (no duplicate function, no new trigger, no schema change).
-- The canonical connections schema (requester_id, recipient_id) is unchanged.

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
    SELECT COALESCE(display_name, split_part(NEW.requester_id::text, '-', 1))
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
