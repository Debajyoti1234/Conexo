-- Phase 3.1A: Plans Backend Foundation
--
-- Creates the production-ready plans, plan_members, and plan_invites tables
-- with indexes, constraints, RLS, triggers, and Storage policies.
-- Additive only — no existing tables modified.
--
-- Compatible with the existing chat schema placeholder:
--   conversations.type IN ('connection', 'plan')
--   conversations.plan_id UUID NULL

-- ============================================================================
-- 1. PLANS
-- ============================================================================

CREATE TABLE public.plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  creator_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,

  title TEXT NOT NULL,

  description TEXT NULL,

  category TEXT NOT NULL,

  mood TEXT NULL,

  cover_url TEXT NULL,

  visibility TEXT NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'private')),

  latitude DOUBLE PRECISION NULL,

  longitude DOUBLE PRECISION NULL,

  starts_at TIMESTAMPTZ NOT NULL,

  capacity INTEGER NOT NULL
    CHECK (capacity > 0),

  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft', 'active', 'full', 'cancelled', 'completed', 'archived')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 2. INDEXES — plans
-- ============================================================================

CREATE INDEX idx_plans_creator_id
  ON public.plans(creator_id);

CREATE INDEX idx_plans_visibility
  ON public.plans(visibility);

CREATE INDEX idx_plans_status
  ON public.plans(status);

CREATE INDEX idx_plans_starts_at
  ON public.plans(starts_at);

CREATE INDEX idx_plans_category
  ON public.plans(category);

CREATE INDEX idx_plans_created_at
  ON public.plans(created_at DESC);

-- Composite partial index for the most common discovery query pattern:
-- public active plans ordered by recency.
CREATE INDEX idx_plans_visibility_status_created
  ON public.plans(visibility, status, created_at DESC)
  WHERE visibility = 'public' AND status = 'active';

-- ============================================================================
-- 3. PLAN MEMBERS
-- ============================================================================

CREATE TABLE public.plan_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  plan_id UUID NOT NULL
    REFERENCES public.plans(id)
    ON DELETE CASCADE,

  user_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,

  role TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('creator', 'member')),

  status TEXT NOT NULL DEFAULT 'joined'
    CHECK (status IN ('pending', 'joined', 'declined', 'left', 'removed')),

  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(plan_id, user_id)
);

-- ============================================================================
-- 4. INDEXES — plan_members
-- ============================================================================

CREATE INDEX idx_plan_members_plan_id
  ON public.plan_members(plan_id);

CREATE INDEX idx_plan_members_user_id
  ON public.plan_members(user_id);

CREATE INDEX idx_plan_members_status
  ON public.plan_members(status);

-- ============================================================================
-- 5. PLAN INVITES
-- ============================================================================

CREATE TABLE public.plan_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  plan_id UUID NOT NULL
    REFERENCES public.plans(id)
    ON DELETE CASCADE,

  inviter_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,

  invitee_id UUID NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,

  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (inviter_id <> invitee_id)
);

-- ============================================================================
-- 6. INDEXES — plan_invites
-- ============================================================================

CREATE INDEX idx_plan_invites_plan_id
  ON public.plan_invites(plan_id);

CREATE INDEX idx_plan_invites_inviter_id
  ON public.plan_invites(inviter_id);

CREATE INDEX idx_plan_invites_invitee_id
  ON public.plan_invites(invitee_id);

CREATE INDEX idx_plan_invites_status
  ON public.plan_invites(status);

-- Partial unique index: only one pending invite per plan+inviter+invitee.
-- Accepted/declined/cancelled rows do not block re-invitation.
CREATE UNIQUE INDEX idx_plan_invites_unique_pending
  ON public.plan_invites(plan_id, inviter_id, invitee_id)
  WHERE status = 'pending';

-- ============================================================================
-- 7. TRIGGER FUNCTIONS
-- ============================================================================

-- Generic updated_at setter (reused across all three tables).
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Auto-create creator membership after a plan is inserted.
-- Guarantees the creator is always a joined 'creator' member without
-- relying on the Flutter client to insert a separate plan_members row.
CREATE OR REPLACE FUNCTION public.create_plan_creator_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.plan_members (plan_id, user_id, role, status, joined_at, updated_at)
  VALUES (NEW.id, NEW.creator_id, 'creator', 'joined', now(), now())
  ON CONFLICT (plan_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Enforce valid state transitions for plan invites.
-- Only the inviter can cancel; only the invitee can accept/decline.
CREATE OR REPLACE FUNCTION public.enforce_plan_invite_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.plan_id <> OLD.plan_id THEN
    RAISE EXCEPTION 'plan_id is immutable';
  END IF;
  IF NEW.inviter_id <> OLD.inviter_id THEN
    RAISE EXCEPTION 'inviter_id is immutable';
  END IF;
  IF NEW.invitee_id <> OLD.invitee_id THEN
    RAISE EXCEPTION 'invitee_id is immutable';
  END IF;
  IF NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable';
  END IF;

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'cancelled' THEN
    IF auth.uid() <> NEW.inviter_id THEN
      RAISE EXCEPTION 'Only inviter can cancel a pending invite';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    IF auth.uid() <> NEW.invitee_id THEN
      RAISE EXCEPTION 'Only invitee can accept a pending invite';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status = 'declined' THEN
    IF auth.uid() <> NEW.invitee_id THEN
      RAISE EXCEPTION 'Only invitee can decline a pending invite';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid plan invite status transition: % → %', OLD.status, NEW.status;
END;
$$;

-- Enforce valid state transitions for plan members.
CREATE OR REPLACE FUNCTION public.enforce_plan_member_transitions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role <> OLD.role THEN
    RAISE EXCEPTION 'role is immutable';
  END IF;
  IF NEW.plan_id <> OLD.plan_id THEN
    RAISE EXCEPTION 'plan_id is immutable';
  END IF;
  IF NEW.user_id <> OLD.user_id THEN
    RAISE EXCEPTION 'user_id is immutable';
  END IF;
  IF NEW.joined_at <> OLD.joined_at THEN
    RAISE EXCEPTION 'joined_at is immutable';
  END IF;
  IF NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'created_at is immutable';
  END IF;

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- pending -> joined (direct join or invite accepted)
  IF OLD.status = 'pending' AND NEW.status = 'joined' THEN
    RETURN NEW;
  END IF;

  -- pending -> declined
  IF OLD.status = 'pending' AND NEW.status = 'declined' THEN
    RETURN NEW;
  END IF;

  -- joined -> left (self only; RLS also enforces auth.uid() = user_id)
  IF OLD.status = 'joined' AND NEW.status = 'left' THEN
    IF auth.uid() <> NEW.user_id THEN
      RAISE EXCEPTION 'Only the member can leave';
    END IF;
    RETURN NEW;
  END IF;

  -- joined -> removed (creator only)
  IF OLD.status = 'joined' AND NEW.status = 'removed' THEN
    IF auth.uid() <> (
      SELECT creator_id FROM public.plans WHERE id = NEW.plan_id
    ) THEN
      RAISE EXCEPTION 'Only the creator can remove a member';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Invalid plan member status transition: % → %', OLD.status, NEW.status;
END;
$$;

-- ============================================================================
-- 8. ATTACH TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS trg_set_plans_updated_at ON public.plans;
CREATE TRIGGER trg_set_plans_updated_at
  BEFORE UPDATE ON public.plans
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_create_plan_creator_membership ON public.plans;
CREATE TRIGGER trg_create_plan_creator_membership
  AFTER INSERT ON public.plans
  FOR EACH ROW
  EXECUTE FUNCTION public.create_plan_creator_membership();

DROP TRIGGER IF EXISTS trg_set_plan_members_updated_at ON public.plan_members;
CREATE TRIGGER trg_set_plan_members_updated_at
  BEFORE UPDATE ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_enforce_plan_member_transitions ON public.plan_members;
CREATE TRIGGER trg_enforce_plan_member_transitions
  BEFORE UPDATE ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_plan_member_transitions();

DROP TRIGGER IF EXISTS trg_set_plan_invites_updated_at ON public.plan_invites;
CREATE TRIGGER trg_set_plan_invites_updated_at
  BEFORE UPDATE ON public.plan_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_enforce_plan_invite_transitions ON public.plan_invites;
CREATE TRIGGER trg_enforce_plan_invite_transitions
  BEFORE UPDATE ON public.plan_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_plan_invite_transitions();

-- ============================================================================
-- 9. ENABLE RLS
-- ============================================================================

ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_invites ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 10. PLANS RLS
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Authenticated can read public plans'
  ) THEN
    CREATE POLICY "Authenticated can read public plans"
      ON public.plans FOR SELECT
      TO authenticated
      USING (visibility = 'public' AND status = 'active');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Creators can read own plans'
  ) THEN
    CREATE POLICY "Creators can read own plans"
      ON public.plans FOR SELECT
      TO authenticated
      USING (auth.uid() = creator_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Members can read joined plans'
  ) THEN
    CREATE POLICY "Members can read joined plans"
      ON public.plans FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.plan_members
          WHERE plan_members.plan_id = plans.id
            AND plan_members.user_id = auth.uid()
            AND plan_members.status = 'joined'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Invitees can read invited plans'
  ) THEN
    CREATE POLICY "Invitees can read invited plans"
      ON public.plans FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.plan_invites
          WHERE plan_invites.plan_id = plans.id
            AND plan_invites.invitee_id = auth.uid()
            AND plan_invites.status = 'pending'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Authenticated can create plans'
  ) THEN
    CREATE POLICY "Authenticated can create plans"
      ON public.plans FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = creator_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Creators can update own plans'
  ) THEN
    CREATE POLICY "Creators can update own plans"
      ON public.plans FOR UPDATE
      TO authenticated
      USING (auth.uid() = creator_id)
      WITH CHECK (auth.uid() = creator_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plans'
      AND policyname = 'Creators can delete own plans'
  ) THEN
    CREATE POLICY "Creators can delete own plans"
      ON public.plans FOR DELETE
      TO authenticated
      USING (auth.uid() = creator_id);
  END IF;
END $$;

-- ============================================================================
-- 11. PLAN MEMBERS RLS
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can read own membership'
  ) THEN
    CREATE POLICY "Users can read own membership"
      ON public.plan_members FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Creators can read plan memberships'
  ) THEN
    CREATE POLICY "Creators can read plan memberships"
      ON public.plan_members FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.plans
          WHERE plans.id = plan_members.plan_id
            AND plans.creator_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Members can read plan participants'
  ) THEN
    CREATE POLICY "Members can read plan participants"
      ON public.plan_members FOR SELECT
      TO authenticated
      USING (
        plan_members.status = 'joined'
        AND EXISTS (
          SELECT 1 FROM public.plan_members pm2
          WHERE pm2.plan_id = plan_members.plan_id
            AND pm2.user_id = auth.uid()
            AND pm2.status = 'joined'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can insert own membership'
  ) THEN
    CREATE POLICY "Users can insert own membership"
      ON public.plan_members FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        AND role = 'member'
        AND status IN ('joined', 'pending')
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can update own membership'
  ) THEN
    CREATE POLICY "Users can update own membership"
      ON public.plan_members FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_members'
      AND policyname = 'Users can delete own membership'
  ) THEN
    CREATE POLICY "Users can delete own membership"
      ON public.plan_members FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================================
-- 12. PLAN INVITES RLS
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_invites'
      AND policyname = 'Inviters can read own invites'
  ) THEN
    CREATE POLICY "Inviters can read own invites"
      ON public.plan_invites FOR SELECT
      TO authenticated
      USING (auth.uid() = inviter_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_invites'
      AND policyname = 'Invitees can read own invites'
  ) THEN
    CREATE POLICY "Invitees can read own invites"
      ON public.plan_invites FOR SELECT
      TO authenticated
      USING (auth.uid() = invitee_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_invites'
      AND policyname = 'Inviters can create invites'
  ) THEN
    CREATE POLICY "Inviters can create invites"
      ON public.plan_invites FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = inviter_id
        AND inviter_id <> invitee_id
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_invites'
      AND policyname = 'Invite participants can update invites'
  ) THEN
    CREATE POLICY "Invite participants can update invites"
      ON public.plan_invites FOR UPDATE
      TO authenticated
      USING (auth.uid() = inviter_id OR auth.uid() = invitee_id)
      WITH CHECK (auth.uid() = inviter_id OR auth.uid() = invitee_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'plan_invites'
      AND policyname = 'Inviters can delete own invites'
  ) THEN
    CREATE POLICY "Inviters can delete own invites"
      ON public.plan_invites FOR DELETE
      TO authenticated
      USING (auth.uid() = inviter_id);
  END IF;
END $$;

-- ============================================================================
-- 13. CHAT INTEGRATION — conversations.plan_id foreign key
-- ============================================================================
--
-- Adds a foreign key from the existing chat schema placeholder
-- conversations.plan_id → plans.id with ON DELETE SET NULL.
--
-- SAFETY:
--   * The existing RPC (get_or_create_connection_conversation) always writes
--     plan_id = NULL, so no existing conversation row violates the FK.
--   * ON DELETE SET NULL preserves chat history if a plan is ever removed.
--   * If a non-null plan_id ever references a missing plan, the ALTER TABLE
--     will fail gracefully inside this DO block and can be retried after
--     cleanup.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'conversations'
      AND constraint_type = 'FOREIGN KEY'
      AND constraint_name = 'conversations_plan_id_fkey'
  ) THEN
    ALTER TABLE public.conversations
      ADD CONSTRAINT conversations_plan_id_fkey
      FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 14. STORAGE — plan-covers bucket
-- ============================================================================
--
-- Path convention:
--   User-uploaded : plans/{creatorId}/{planId}/cover.{ext}
--   Default covers: defaults/{moodSlug}.jpg
--
-- The future Flutter repository should set cover_url to the full storage path.
-- Default covers are backend-seeded; users cannot write to the defaults/ folder.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('plan-covers', 'plan-covers', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Creators can upload plan covers'
  ) THEN
    CREATE POLICY "Creators can upload plan covers"
      ON storage.objects FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'plan-covers'
        AND (storage.foldername(name))[1] = 'plans'
        AND (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Creators can update own plan covers'
  ) THEN
    CREATE POLICY "Creators can update own plan covers"
      ON storage.objects FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'plan-covers'
        AND (storage.foldername(name))[1] = 'plans'
        AND (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Creators can delete own plan covers'
  ) THEN
    CREATE POLICY "Creators can delete own plan covers"
      ON storage.objects FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'plan-covers'
        AND (storage.foldername(name))[1] = 'plans'
        AND (storage.foldername(name))[2] = auth.uid()::text
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Authenticated can read plan covers'
  ) THEN
    CREATE POLICY "Authenticated can read plan covers"
      ON storage.objects FOR SELECT
      TO authenticated
      USING (bucket_id = 'plan-covers');
  END IF;
END $$;
