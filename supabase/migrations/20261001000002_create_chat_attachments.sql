-- Chat 6.3A: Chat Attachments Storage Bucket + Policies
-- Creates the private chat-attachments bucket and row-level security policies
-- scoped to conversation membership and message ownership.

-- ============================================================================
-- 1. STORAGE BUCKET
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. STORAGE POLICIES
-- ============================================================================

-- Upload: conversation members can upload attachments for conversations they
-- belong to. The path convention is chat-attachments/{conversation_id}/{uuid}.jpg
CREATE POLICY "Members can upload chat attachments"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'chat-attachments'
    AND (storage.foldername(name))[1] = 'chat-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      WHERE cm.conversation_id::text = (storage.foldername(name))[2]
        AND cm.user_id = auth.uid()
    )
  );

-- Read: conversation members can read attachments for conversations they
-- belong to. The media_url stored in messages matches the storage object name.
CREATE POLICY "Members can read chat attachments"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'chat-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.messages m
      JOIN public.conversation_members cm
        ON cm.conversation_id = m.conversation_id
      WHERE m.media_url = objects.name
        AND cm.user_id = auth.uid()
    )
  );

-- Delete: the message sender can delete their own attachment.
CREATE POLICY "Senders can delete chat attachments"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'chat-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.messages m
      WHERE m.media_url = objects.name
        AND m.sender_id = auth.uid()
    )
  );