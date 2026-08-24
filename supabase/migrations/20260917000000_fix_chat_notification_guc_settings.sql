-- ============================================================================
-- Fix: Set GUC settings for chat push notification trigger
-- ============================================================================
--
-- The notify_chat_message() trigger function requires these GUC settings:
--   app.notify_edge_url      - Edge Function URL for notify-chat-message
--   app.supabase_anon_key    - Supabase anon key for Edge Function auth
--
-- Without these settings, the trigger silently returns without calling the
-- Edge Function, causing push notifications to never fire.
--
-- After running this migration, restart the Supabase instance or run:
--   SELECT pg_reload_conf();
-- ============================================================================

-- Set the Edge Function URL for chat notifications
-- Replace with your actual Edge Function URL if different
ALTER DATABASE postgres SET app.notify_edge_url TO 'https://wlfitdzhvfhuqgxwreed.supabase.co/functions/v1/notify-chat-message';

-- Set the Supabase anon key for Edge Function authorization
-- Replace with your actual anon key if different
ALTER DATABASE postgres SET app.supabase_anon_key TO 'sb_publishable_wOqD0TUeyMU-j2-IECf6bA_8Xtl-C0M';

-- Verify the settings are set correctly
SELECT
  current_setting('app.notify_edge_url', true) AS notify_edge_url,
  current_setting('app.supabase_anon_key', true) AS supabase_anon_key;
