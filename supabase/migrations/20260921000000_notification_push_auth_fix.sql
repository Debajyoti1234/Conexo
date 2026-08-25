-- ============================================================================
-- Notification Push Auth Fix
-- ============================================================================
--
-- ROOT CAUSE (diagnosed against LIVE production):
--   The four event notification trigger functions built the Authorization
--   header as:
--       'Bearer ' || current_setting('app.supabase_anon_key', true)
--   In production the GUC app.supabase_anon_key is NULL (ALTER DATABASE cannot
--   set it on Supabase Cloud). NULL concatenation yields a NULL header, so the
--   Edge Function gateway (verify_jwt = true) rejected every push with
--   HTTP 401 "UNAUTHORIZED_NO_AUTH_HEADER". Activity rows were still inserted
--   (same transaction), which is why Activity worked but Push did not.
--
-- FIX (matches the PROVEN working notify_chat_message() pattern):
--   Resolve the auth key from the GUC, and fall back to the project's real
--   anon JWT when the GUC is unset. This is the identical mechanism the live
--   chat notification function already uses successfully.
--
-- This migration only CREATE OR REPLACEs the four existing functions. It does
-- NOT create new triggers, tables, or Edge Functions, and does not touch the
-- Activity INSERT logic, RLS, chat, or FCM transport.
-- ============================================================================

-- ============================================================================
-- 1. CONNECTION REQUEST ACCEPTED
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_connection_accepted_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
  v_auth_key text;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT COALESCE(display_name, split_part(NEW.recipient_id::text, '-', 1))
      INTO v_requester_name
      FROM public.profiles
      WHERE id = NEW.recipient_id;

    INSERT INTO public.notifications (
      user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at
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

    v_auth_key := current_setting('app.supabase_anon_key', true);
    IF v_auth_key IS NULL OR v_auth_key = '' THEN
      v_auth_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsZml0ZHpodmZodXFneHdyZWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODA0NDcsImV4cCI6MjEwMTc1NjQ0N30.McdwS9cDIiPNykUpcJJG3gDelgsDRtsDfVnXpxpgdK4';
    END IF;

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_auth_key
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

-- ============================================================================
-- 2. PLAN JOIN REQUEST
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_join_request_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_id uuid;
  v_auth_key text;
BEGIN
  IF NEW.status = 'pending' AND NEW.role = 'member' THEN
    SELECT p.title, p.creator_id
      INTO v_plan_title, v_host_id
      FROM public.plans p
      WHERE p.id = NEW.plan_id;

    INSERT INTO public.notifications (
      user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at
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

    v_auth_key := current_setting('app.supabase_anon_key', true);
    IF v_auth_key IS NULL OR v_auth_key = '' THEN
      v_auth_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsZml0ZHpodmZodXFneHdyZWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODA0NDcsImV4cCI6MjEwMTc1NjQ0N30.McdwS9cDIiPNykUpcJJG3gDelgsDRtsDfVnXpxpgdK4';
    END IF;

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_auth_key
      ),
      body := jsonb_build_object(
        'event_type', 'plan_join_request',
        'recipient_id', v_host_id,
        'actor_id', NEW.user_id,
        'title', 'New join request',
        'body', format('"%s" requested to join your plan "%s".', COALESCE((SELECT display_name FROM public.profiles WHERE id = NEW.user_id), 'Someone'), COALESCE(v_plan_title, 'your plan')),
        'entity_id', NEW.plan_id,
        'entity_type', 'plan'
      ),
      timeout_milliseconds := 10000
    );
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 3. PLAN INVITATION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_name text;
  v_auth_key text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT p.title, COALESCE(pr.display_name, split_part(p.creator_id::text, '-', 1))
      INTO v_plan_title, v_host_name
    FROM public.plans p
    LEFT JOIN public.profiles pr ON pr.id = p.creator_id
    WHERE p.id = NEW.plan_id;

    INSERT INTO public.notifications (
      user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at
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

    v_auth_key := current_setting('app.supabase_anon_key', true);
    IF v_auth_key IS NULL OR v_auth_key = '' THEN
      v_auth_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsZml0ZHpodmZodXFneHdyZWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODA0NDcsImV4cCI6MjEwMTc1NjQ0N30.McdwS9cDIiPNykUpcJJG3gDelgsDRtsDfVnXpxpgdK4';
    END IF;

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_auth_key
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

-- ============================================================================
-- 4. CONNECTION REQUEST
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_connection_request_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
  v_auth_key text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(display_name, split_part(NEW.requester_id::text, '-', 1))
      INTO v_requester_name
    FROM public.profiles
    WHERE id = NEW.requester_id;

    INSERT INTO public.notifications (
      user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at
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

    v_auth_key := current_setting('app.supabase_anon_key', true);
    IF v_auth_key IS NULL OR v_auth_key = '' THEN
      v_auth_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsZml0ZHpodmZodXFneHdyZWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODA0NDcsImV4cCI6MjEwMTc1NjQ0N30.McdwS9cDIiPNykUpcJJG3gDelgsDRtsDfVnXpxpgdK4';
    END IF;

    PERFORM net.http_post(
      url := 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-event',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_auth_key
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
