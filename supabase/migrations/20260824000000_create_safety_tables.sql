-- Phase 9.1D: Safety & Moderation Foundation
--
-- Creates safety_reports and blocked_users tables with indexes and RLS.
-- Additive only — no existing tables modified.

-- ============================================================================
-- 1. SAFETY REPORTS
-- ============================================================================

CREATE TABLE public.safety_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  reporter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  reporter_name_snapshot TEXT NULL,
  reported_name_snapshot TEXT NULL,

  report_type TEXT NOT NULL,
  description TEXT NULL,

  screenshot_path TEXT NULL,

  status TEXT NOT NULL DEFAULT 'pending',

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (reporter_user_id != reported_user_id)
);

CREATE INDEX idx_safety_reports_reporter
  ON public.safety_reports(reporter_user_id);

CREATE INDEX idx_safety_reports_reported
  ON public.safety_reports(reported_user_id);

CREATE INDEX idx_safety_reports_status
  ON public.safety_reports(status);

CREATE INDEX idx_safety_reports_created_at
  ON public.safety_reports(created_at DESC);

-- ============================================================================
-- 2. BLOCKED USERS
-- ============================================================================

CREATE TABLE public.blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  blocker_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(blocker_user_id, blocked_user_id),

  CHECK (blocker_user_id != blocked_user_id)
);

CREATE INDEX idx_blocked_users_blocker
  ON public.blocked_users(blocker_user_id);

CREATE INDEX idx_blocked_users_blocked
  ON public.blocked_users(blocked_user_id);

-- ============================================================================
-- 3. ENABLE RLS
-- ============================================================================

ALTER TABLE public.safety_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. SAFETY REPORTS RLS
-- ============================================================================

-- Reporters can view their own reports.
CREATE POLICY "Reporters can view own reports"
  ON public.safety_reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Authenticated users can create reports about other users.
CREATE POLICY "Authenticated users can create reports"
  ON public.safety_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND reporter_user_id != reported_user_id
  );

-- No UPDATE/DELETE policies — reports are immutable from the client.

-- ============================================================================
-- 5. BLOCKED USERS RLS
-- ============================================================================

-- Users can view their own blocks (as blocker).
CREATE POLICY "Users can view own blocks"
  ON public.blocked_users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = blocker_user_id);

-- Users can create their own blocks.
CREATE POLICY "Users can block others"
  ON public.blocked_users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = blocker_user_id
    AND blocker_user_id != blocked_user_id
  );

-- Users can remove their own blocks.
CREATE POLICY "Users can unblock"
  ON public.blocked_users
  FOR DELETE
  TO authenticated
  USING (auth.uid() = blocker_user_id);

-- No UPDATE policy required.
