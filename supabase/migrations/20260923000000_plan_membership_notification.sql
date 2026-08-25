-- ============================================================================
-- Plan Membership Success Notification (Activity + Push)
-- ============================================================================
--
-- Adds ONE canonical membership-activation notification, delivered when a user
-- becomes an active plan member (role='member', status='joined'). This covers
-- BOTH activation paths through a single authoritative event on plan_members:
--
--   1. Plan Join Request accepted  → approve_plan_member(): UPDATE pending→joined
--   2. Plan Invitation accepted    → accept_plan_invitation(): INSERT/UPSERT joined
--
-- Message (Activity + Push):
--   "You are now part of "<Plan>" hosted by <Creator>. Tap to open chat room."
--
-- Recipient = the newly joined member (NEW.user_id). Actor = plan creator/host.
--
-- DUPLICATE PROTECTION:
--   The single trigger below is the ONLY producer of this notification. The
--   inline notification previously created inside accept_plan_invitation() is
--   REMOVED here so invitation acceptance does not double-notify. One domain
--   event (membership becomes joined) → one Activity row + one push.
--
-- The Activity reuses the existing kind='plan_invitation' + entity_type='plan_chat'
-- convention that the Flutter client already routes to the Plan Chat, so no new
-- NotificationKind is introduced. Push uses event_type='plan_invitation' with
-- entity_type='plan_chat', which the client already recognizes for display.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_plan_membership_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_id uuid;
  v_host_name text;
  v_auth_key text;
  v_body text;
  v_should_notify boolean := false;
BEGIN
  -- Only notify real members (never the creator's own auto-membership row).
  IF NEW.role <> 'member' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Invitation acceptance inserts the member directly as joined.
    IF NEW.status = 'joined' THEN
      v_should_notify := true;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Join-request approval transitions pending -> joined.
    IF OLD.status = 'pending' AND NEW.status = 'joined' THEN
      v_should_notify := true;
    END IF;
  END IF;

  IF NOT v_should_notify THEN
    RETURN NEW;
  END IF;

  SELECT p.title, p.creator_id
    INTO v_plan_title, v_host_id
    FROM public.plans p
    WHERE p.id = NEW.plan_id;

  SELECT COALESCE(display_name, split_part(v_host_id::text, '-', 1))
    INTO v_host_name
    FROM public.profiles
    WHERE id = v_host_id;

  v_body := format(
    'You are now part of "%s" hosted by %s. Tap to open chat room.',
    COALESCE(v_plan_title, 'a plan'),
    COALESCE(v_host_name, 'the host')
  );

  -- Activity (reuses existing plan_invitation + plan_chat routing convention).
  INSERT INTO public.notifications (
    user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at
  ) VALUES (
    NEW.user_id,
    v_host_id,
    'plan_invitation',
    COALESCE(v_plan_title, 'Plan'),
    v_body,
    NEW.plan_id,
    'plan_chat',
    false,
    now()
  );

  -- Push via the existing notify-event Edge Function.
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
      'event_type', 'plan_invitation',
      'recipient_id', NEW.user_id,
      'actor_id', v_host_id,
      'title', 'Conexo',
      'body', v_body,
      'entity_id', NEW.plan_id,
      'entity_type', 'plan_chat'
    ),
    timeout_milliseconds := 10000
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_plan_membership_notification ON public.plan_members;
CREATE TRIGGER trg_create_plan_membership_notification
  AFTER INSERT OR UPDATE ON public.plan_members
  FOR EACH ROW
  EXECUTE FUNCTION public.create_plan_membership_notification();

-- ============================================================================
-- Dedup: remove the inline membership notification from accept_plan_invitation.
-- The canonical trigger above now produces exactly one Activity + one push when
-- the plan_members row becomes joined. Everything else in the RPC is preserved.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.accept_plan_invitation(
  p_invite_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id, plan_id, inviter_id, invitee_id, status
    INTO v_invite
  FROM public.plan_invites
  WHERE id = p_invite_id;

  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  IF auth.uid() <> v_invite.invitee_id THEN
    RAISE EXCEPTION 'Only the invitee can accept this invitation';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'Invitation is no longer pending';
  END IF;

  UPDATE public.plan_invites
  SET status = 'accepted'
  WHERE id = p_invite_id;

  -- Membership activation. The AFTER INSERT/UPDATE trigger
  -- create_plan_membership_notification() emits the single membership-success
  -- Activity + push; no notification is created here (prevents duplicates).
  INSERT INTO public.plan_members (plan_id, user_id, role, status, joined_at, updated_at)
  VALUES (v_invite.plan_id, v_invite.invitee_id, 'member', 'joined', now(), now())
  ON CONFLICT (plan_id, user_id) DO UPDATE
    SET status = 'joined',
        updated_at = now()
    WHERE plan_members.status <> 'joined';
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_plan_invitation(uuid) TO authenticated;
