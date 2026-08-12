-- Phase 9.5.2: Connection Chat RPC
-- Securely creates/finds a conversation for an accepted connection.

CREATE OR REPLACE FUNCTION public.get_or_create_connection_conversation(
  p_connection_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation_id uuid;
  v_requester_id uuid;
  v_recipient_id uuid;
  v_current_user uuid;
BEGIN
  v_current_user := auth.uid();
  IF v_current_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT requester_id, recipient_id INTO v_requester_id, v_recipient_id
  FROM public.connections
  WHERE id = p_connection_id AND status = 'accepted';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Connection not found or not accepted';
  END IF;

  IF v_current_user <> v_requester_id AND v_current_user <> v_recipient_id THEN
    RAISE EXCEPTION 'Not a participant of this connection';
  END IF;

  v_conversation_id := md5(p_connection_id::text || '-conexo-connection-v1')::uuid;

  INSERT INTO public.conversations (id, type, plan_id)
  VALUES (v_conversation_id, 'connection', NULL)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_conversation_id, v_requester_id), (v_conversation_id, v_recipient_id)
  ON CONFLICT (conversation_id, user_id) DO NOTHING;

  RETURN v_conversation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_connection_conversation(uuid) TO authenticated;
