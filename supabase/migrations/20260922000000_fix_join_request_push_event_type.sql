-- ============================================================================
-- Plan Join Request Push — event_type alignment fix
-- ============================================================================
--
-- ROOT CAUSE (diagnosed against LIVE production):
--   The join-request trigger delivered the PUSH with
--       'event_type' = 'plan_join_request'
--   which notify-event forwards to the FCM data payload as
--       data.type = 'plan_join_request'.
--   The Flutter client, however, listens for the push type 'join_request'
--   in ALL handlers (web foreground, Android foreground, tap routing) and
--   parses the Activity kind as 'join_request' too. The push string
--   'plan_join_request' matched none of them, so the foreground push was
--   never displayed and taps were not routed. Activity worked because the
--   Activity row is written with kind = 'join_request' (correct), independent
--   of the mismatched push event_type.
--
-- FIX (smallest possible, server-side, immediately effective for installed
-- apps that already listen for 'join_request'):
--   Change ONLY the push event_type from 'plan_join_request' to 'join_request'.
--   The Activity INSERT (kind='join_request'), recipient (plan host), auth
--   fallback, URL, and all other behavior are preserved exactly.
--
-- This CREATE OR REPLACE affects only create_join_request_notification(). It
-- does NOT touch connection_request, connection_accepted, plan_invitation,
-- notify-event, notify-chat-message, RLS, Activity architecture, or FCM
-- transport. No new trigger, table, or Edge Function is created.
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
        'event_type', 'join_request',
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
