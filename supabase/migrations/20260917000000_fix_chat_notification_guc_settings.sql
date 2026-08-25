-- ============================================================================
-- Fix: Set GUC settings for chat push notification trigger
-- ============================================================================
--
-- The notify_chat_message() trigger function requires these GUC settings:
--   app.notify_edge_url      - Edge Function URL for notify-chat-message
--   app.supabase_anon_key    - Supabase anon key for Edge Function auth
--
-- NOTE: ALTER DATABASE requires superuser privileges and is not available
-- on Supabase Cloud. These settings must be configured through the Supabase
-- Dashboard (Settings → Database → Customized settings) or via a superuser
-- session. The chat notification system will skip Edge Function calls if
-- these GUC values are not set.
--
-- After configuring these settings in the Dashboard, the trigger will
-- automatically pick them up.
-- ============================================================================

-- Check current settings (returns NULL if not set)
SELECT
  current_setting('app.notify_edge_url', true) AS notify_edge_url,
  current_setting('app.supabase_anon_key', true) AS supabase_anon_key;
