-- ============================================================================
-- Chat P5: phone push notifications for chat messages
-- ============================================================================
--
-- Backend-authoritative push. When a new message is inserted, an AFTER INSERT
-- trigger invokes a SECURITY DEFINER function that calls the
-- `notify-chat-message` Supabase Edge Function via pg_net. The Edge Function
-- (running with the service role) resolves the conversation type, the eligible
-- recipients, enforces mute + block rules, deduplicates via
-- conversation_members.last_notified_at, and delivers FCM v1 pushes.
--
-- This is fully server-side: it does NOT depend on the Flutter app being
-- alive. Pushes are delivered to the Android notification shade, lock screen,
-- background, and terminated-app states.
--
-- Prerequisites (configured outside this migration):
--   * pg_net extension enabled (Supabase Dashboard → Database → Extensions)
--   * Edge Function `notify-chat-message` deployed
--   * Edge Function secret FCM_SERVICE_ACCOUNT_JSON set
--   * GUC app.notify_edge_url set to the function URL
-- ============================================================================

-- pg_net is required for the trigger to reach the Edge Function.
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================================
-- notify_chat_message()
-- ============================================================================
-- SECURITY DEFINER trigger helper. It only forwards real, newly-created,
-- non-deleted, non-system messages. Everything else is ignored so that join
-- system messages, soft-deleted rows, and message UPDATEs never fan out a push.
CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_edge_url TEXT;
  v_response BIGINT;
BEGIN
  -- Only real user messages trigger push. System messages (plan join events)
  -- and anything already soft-deleted never generate a notification.
  IF NEW.type = 'system' OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_edge_url := current_setting('app.notify_edge_url', true);
  EXCEPTION
    WHEN undefined_object THEN
      -- Edge Function URL not configured; swallow so message INSERT still
      -- succeeds. Push is degraded, not blocked.
      RETURN NEW;
  END;

  IF v_edge_url IS NULL OR v_edge_url = '' THEN
    RETURN NEW;
  END IF;

  -- Fire-and-forget call to the Edge Function. The function is idempotent on
  -- message id, so pg_net retries cannot cause duplicate notifications.
  SELECT net.http_post(
    url     := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.supabase_anon_key', true)
    ),
    body    := jsonb_build_object('message_id', NEW.id),
    timeout_milliseconds := 10000
  ) INTO v_response;

  RETURN NEW;
END;
$$;

-- ============================================================================
-- Trigger on messages
-- ============================================================================
DROP TRIGGER IF EXISTS trg_notify_chat_message ON public.messages;
CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message();
