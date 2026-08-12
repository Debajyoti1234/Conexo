import os

migrations = {
    '20260823000000_create_conversation_mutes.sql': """-- Phase 9.5.3: Conversation mutes
CREATE TABLE public.conversation_mutes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  muted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

CREATE INDEX idx_conversation_mutes_user_id ON public.conversation_mutes(user_id);
CREATE INDEX idx_conversation_mutes_conversation_id ON public.conversation_mutes(conversation_id);

ALTER TABLE public.conversation_mutes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own mutes"
  ON public.conversation_mutes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mute"
  ON public.conversation_mutes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mute"
  ON public.conversation_mutes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own mute"
  ON public.conversation_mutes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
""",
    '20260824000000_create_blocks.sql': """-- Phase 9.5.3: Blocks
CREATE TABLE public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX idx_blocks_blocker_id ON public.blocks(blocker_id);
CREATE INDEX idx_blocks_blocked_id ON public.blocks(blocked_id);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own blocks"
  ON public.blocks
  FOR SELECT
  TO authenticated
  USING (auth.uid() = blocker_id);

CREATE POLICY "Users can insert own block"
  ON public.blocks
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = blocker_id AND blocker_id <> blocked_id);

CREATE POLICY "Users can delete own block"
  ON public.blocks
  FOR DELETE
  TO authenticated
  USING (auth.uid() = blocker_id);
""",
    '20260825000000_create_reports.sql': """-- Phase 9.5.3: Reports
CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'fake_profile', 'other')),
  CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed'))
);

CREATE INDEX idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX idx_reports_reported_id ON public.reports(reported_id);
CREATE INDEX idx_reports_status ON public.reports(status);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own reports"
  ON public.reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_id);

CREATE POLICY "Users can insert reports"
  ON public.reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id AND reporter_id <> reported_id);

-- No UPDATE/DELETE policies — admin/service role only
""",
    '20260826000000_create_user_devices.sql': """-- Phase 9.5.3: User devices for push notifications
CREATE TABLE public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  push_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NULL,
  UNIQUE(push_token)
);

CREATE INDEX idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_push_token ON public.user_devices(push_token);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own devices"
  ON public.user_devices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device"
  ON public.user_devices
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device"
  ON public.user_devices
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own device"
  ON public.user_devices
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
""",
    '20260827000000_add_last_notified_at.sql': """-- Phase 9.5.3: Add last_notified_at for notification deduplication
ALTER TABLE public.conversation_members
  ADD COLUMN IF NOT EXISTS last_notified_at TIMESTAMPTZ NULL;

CREATE INDEX idx_conversation_members_last_notified_at
  ON public.conversation_members(conversation_id, last_notified_at)
  WHERE last_notified_at IS NOT NULL;
"""
}

for filename, content in migrations.items():
    filepath = os.path.join('supabase', 'migrations', filename)
    with open(filepath, 'w') as f:
        f.write(content)
    print(f'Created {filepath}')
