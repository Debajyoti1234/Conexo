-- ============================================================================
-- Notification Phase: Event-driven Activity + Push notifications
-- ============================================================================
--
-- Adds server-side notification triggers for:
--   1. Connection request accepted (connections UPDATE pending -> accepted)
--   2. Plan join request (plan_members INSERT pending)
--   3. Push delivery coordination via notify-event Edge Function
--
-- Preserves existing Plan Invitation and Connection Request Activity triggers.
-- ============================================================================

-- ============================================================================
-- 1. HELPER: safe actor display name
-- ============================================================================

CREATE OR REPLACE FUNCTION public._notification_actor_name(p_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT display_name FROM public.profiles WHERE id = p_user_id),
    split_part(p_user_id::text, '-', 1)
  );
$$;

-- ============================================================================
-- 2. CONNECTION REQUEST ACCEPTED
-- ============================================================================
--
-- Fires when a pending connection request is accepted.
-- Notifies the ORIGINAL REQUESTER (not the acceptor).

CREATE OR REPLACE FUNCTION public.create_connection_accepted_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT COALESCE(display_name, split_part(NEW.recipient_id::text, '-', 1))
      INTO v_requester_name
      FROM public.profiles
      WHERE id = NEW.recipient_id;

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
      NEW.requester_id,
      NEW.recipient_id,
      'request_accepted',
      'Connection accepted',
      format('"%s" accepted your connection request.', COALESCE(v_requester_name, 'Someone')),
      NEW.id,
      'connection_accepted',
      false,
      now()
    );

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
      ),
      body := jsonb_build_object(
        'event_type', 'connection_accepted',
        'recipient_id', NEW.requester_id,
        'actor_id', NEW.recipient_id,
        'title', 'Connection accepted',
        'body', format('"%s" accepted your connection request.', COALESCE(v_requester_name, 'Someone')),
        'entity_id', NEW.id,
        'entity_type', 'connection_accepted'
      ),
      timeout_milliseconds := 10000
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_connection_accepted_notification ON public.connections;
CREATE TRIGGER trg_create_connection_accepted_notification
  AFTER UPDATE ON public.connections
  FOR EACH ROW
  EXECUTE FUNCTION public.create_connection_accepted_notification();

-- ============================================================================
-- 3. PLAN JOIN REQUEST
-- ============================================================================
--
-- Fires when a user requests to join a plan (plan_members INSERT pending).
-- Notifies the PLAN HOST/CREATOR.

CREATE OR REPLACE FUNCTION public.create_join_request_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_name text;
  v_host_id uuid;
BEGIN
  IF NEW.status = 'pending' AND NEW.role = 'member' THEN
    SELECT p.title, p.creator_id
      INTO v_plan_title, v_host_id
      FROM public.plans p
      WHERE p.id = NEW.plan_id;

    SELECT COALESCE(display_name, split_part(v_host_id::text, '-', 1))
      INTO v_host_name
      FROM public.profiles
      WHERE id = v_host_id;

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
      v_host_id,
      NEW.user_id,
      'join_request',
      'New join request',
      format('"%s" requested to join your plan "%s".', COALESCE((SELECT display_name FROM public.profiles WHERE id = NEW.user_id), 'Someone'), COALESCE(v_plan_title, 'your plan')),
      NEW.plan_id,
      'plan_join_request',
      false,
      now()
    );

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
      ),
      body := jsonb_build_object(
        'event_type', 'plan_join_request',
        'recipient_id', v_host_id,
        'actor_id', NEW.user_id,
        'title', 'New join request',
        'body', format('"%s" requested to join your plan "%s".', COALESCE((SELECT display_name FROM public.profiles WHERE id = NEW.user_id), 'Someone'), COALESCE(v_plan_title, 'your plan')),
        'entity_id', NEW.plan_id,
        'entity_type', 'plan_join_request'
      ),
      timeout_milliseconds := 10000
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_join_request_notification ON public.plan_members;
CREATE TRIGGER trg_create_join_request_notification
  AFTER INSERT ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.create_join_request_notification();

-- ============================================================================
-- 4. PLAN INVITATION PUSH
-- ============================================================================
--
-- Extends the existing create_invitation_notification() trigger to also fire
-- push via notify-event. Activity is preserved exactly.

CREATE OR REPLACE FUNCTION public.create_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_name text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT p.title, COALESCE(pr.display_name, split_part(p.creator_id::text, '-', 1))
      INTO v_plan_title, v_host_name
    FROM public.plans p
    LEFT JOIN public.profiles pr ON pr.id = p.creator_id
    WHERE p.id = NEW.plan_id;

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
      NEW.invitee_id,
      NEW.inviter_id,
      'plan_invitation',
      COALESCE(v_plan_title, 'Plan invitation'),
      format('You got a new invitation for "%s", hosted by "%s".', COALESCE(v_plan_title, 'a plan'), COALESCE(v_host_name, 'someone')),
      NEW.plan_id,
      'plan',
      false,
      now()
    );

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
      ),
      body := jsonb_build_object(
        'event_type', 'plan_invitation',
        'recipient_id', NEW.invitee_id,
        'actor_id', NEW.inviter_id,
        'title', COALESCE(v_plan_title, 'Plan invitation'),
        'body', format('You got a new invitation for "%s", hosted by "%s".', COALESCE(v_plan_title, 'a plan'), COALESCE(v_host_name, 'someone')),
        'entity_id', NEW.plan_id,
        'entity_type', 'plan'
      ),
      timeout_milliseconds := 10000
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_invitation_notification ON public.plan_invites;
CREATE TRIGGER trg_create_invitation_notification
  AFTER INSERT ON public.plan_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.create_invitation_notification();

-- ============================================================================
-- 5. CONNECTION REQUEST PUSH
-- ============================================================================
--
-- Extends the existing create_connection_request_notification() trigger to
-- also fire push via notify-event. Activity is preserved exactly.

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

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
      ),
      body := jsonb_build_object(
        'event_type', 'connection_request',
        'recipient_id', NEW.recipient_id,
        'actor_id', NEW.requester_id,
        'title', 'New connection request',
        'body', format('"%s" wants to connect with you.', COALESCE(v_requester_name, 'Someone')),
        'entity_id', NEW.id,
        'entity_type', 'connection_request'
      ),
      timeout_milliseconds := 10000
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
