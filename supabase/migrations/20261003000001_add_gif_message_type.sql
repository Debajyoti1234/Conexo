-- Phase 9.5.2: Allow GIF messages
-- Adds 'gif' to the messages.type CHECK constraint.
-- Preserves every existing allowed type: text, voice, image, call_event, system.
-- No other tables, columns, RLS, or business logic are touched.

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_type_check;

ALTER TABLE public.messages
  ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text', 'voice', 'image', 'call_event', 'system', 'gif'));