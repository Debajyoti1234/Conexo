-- P1.2B.11: Plan Invitation Backend Foundation
--
-- Adds SECURITY DEFINER RPCs for the plan invitation lifecycle and a
-- lightweight trigger to create a notification when a pending invitation
-- is inserted. Reuses the existing `plan_invites` table, its state-machine
-- trigger, and the `notifications` table from P1.2B.10B.

-- ============================================================================
-- 1. INVITE RPC
-- ============================================================================
--
-- Only the plan creator may call this. The invitee must be an accepted
-- connection of the creator. Duplicate pending invitations are silently
-- ignored (handled by the unique index on plan_invites).

CREATE OR REPLACE FUNCTION public.invite_to_plan(
  p_plan_id uuid,
  p_invitee_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_creator_id uuid;
  v_plan_exists boolean;
  v_connection_exists boolean;
  v_invitee_already_joined boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_plan_id IS NULL OR p_invitee_id IS NULL THEN
    RAISE EXCEPTION 'plan_id and invitee_id are required';
  END IF;

  IF auth.uid() = p_invitee_id THEN
    RAISE EXCEPTION 'Cannot invite yourself';
  END IF;

  SELECT creator_id INTO v_creator_id
  FROM public.plans
  WHERE id = p_plan_id;

  IF v_creator_id IS NULL THEN
    RAISE EXCEPTION 'Plan not found';
  END IF;

  IF auth.uid() <> v_creator_id THEN
    RAISE EXCEPTION 'Only the plan creator can send invitations';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.plans WHERE id = p_plan_id)
    INTO v_plan_exists;
  IF NOT v_plan_exists THEN
    RAISE EXCEPTION 'Plan not found';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.connections
    WHERE (
      (connections.requester_id = auth.uid()
       AND connections.recipient_id = p_invitee_id)
      OR
      (connections.recipient_id = auth.uid()
       AND connections.requester_id = p_invitee_id)
    )
    AND connections.status = 'accepted'
  ) INTO v_connection_exists;

  IF NOT v_connection_exists THEN
    RAISE EXCEPTION 'You can only invite accepted connections';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.plan_members
    WHERE plan_id = p_plan_id
      AND user_id = p_invitee_id
      AND status = 'joined'
  ) INTO v_invitee_already_joined;

  IF v_invitee_already_joined THEN
    RAISE EXCEPTION 'This user is already a member of the plan';
  END IF;

  INSERT INTO public.plan_invites (plan_id, inviter_id, invitee_id, status)
  VALUES (p_plan_id, auth.uid(), p_invitee_id, 'pending')
  ON CONFLICT (plan_id, inviter_id, invitee_id) WHERE status = 'pending' DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.invite_to_plan(uuid, uuid) TO authenticated;

-- ============================================================================
-- 2. ACCEPT RPC
-- ============================================================================
--
-- Only the invitee may accept. On acceptance, the invitee is inserted into
-- plan_members as a joined member (if not already present). The existing
-- capacity trigger and join system message trigger fire automatically.

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

  INSERT INTO public.plan_members (plan_id, user_id, role, status, joined_at, updated_at)
  VALUES (v_invite.plan_id, v_invite.invitee_id, 'member', 'joined', now(), now())
  ON CONFLICT (plan_id, user_id) DO UPDATE
    SET status = 'joined',
        updated_at = now()
    WHERE plan_members.status <> 'joined';

  IF FOUND THEN
    INSERT INTO public.notifications (
      user_id,
      actor_id,
      kind,
      title,
      body,
      entity_id,
      entity_type,
      read,
      created_at
    ) VALUES (
      v_invite.invitee_id,
      v_invite.invitee_id,
      'plan_invitation',
      COALESCE((SELECT title FROM public.plans WHERE id = v_invite.plan_id), 'Plan'),
      format('You are now part of the plan "%s". Tap to enter the chat room.', COALESCE((SELECT title FROM public.plans WHERE id = v_invite.plan_id), 'a plan')),
      v_invite.plan_id,
      'plan_chat',
      false,
      now()
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_plan_invitation(uuid) TO authenticated;

-- ============================================================================
-- 3. DECLINE RPC
-- ============================================================================
--
-- Only the invitee may decline.

CREATE OR REPLACE FUNCTION public.decline_plan_invitation(
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

  SELECT id, invitee_id, status
    INTO v_invite
  FROM public.plan_invites
  WHERE id = p_invite_id;

  IF v_invite.id IS NULL THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;

  IF auth.uid() <> v_invite.invitee_id THEN
    RAISE EXCEPTION 'Only the invitee can decline this invitation';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'Invitation is no longer pending';
  END IF;

  UPDATE public.plan_invites
  SET status = 'declined'
  WHERE id = p_invite_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_plan_invitation(uuid) TO authenticated;

-- ============================================================================
-- 4. NOTIFICATION TRIGGER
-- ============================================================================
--
-- When a pending invitation is inserted, create a notification for the
-- invitee. The notification kind is `plan_invitation` and the entity_id
-- carries the plan id.

CREATE OR REPLACE FUNCTION public.create_invitation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan_title text;
  v_host_name text;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT p.title, COALESCE(pr.display_name, split_part(p.creator_id::text, '-', 1))
      INTO v_plan_title, v_host_name
    FROM public.plans p
    LEFT JOIN public.profiles pr ON pr.id = p.creator_id
    WHERE p.id = NEW.plan_id;

    INSERT INTO public.notifications (
      user_id,
      actor_id,
      kind,
      title,
      body,
      entity_id,
      entity_type,
      read,
      created_at
    ) VALUES (
      NEW.invitee_id,
      NEW.inviter_id,
      'plan_invitation',
      COALESCE(v_plan_title, 'Plan invitation'),
      format('You got a new invitation for "%s", hosted by "%s".', COALESCE(v_plan_title, 'a plan'), COALESCE(v_host_name, 'someone')),
      NEW.plan_id,
      'plan',
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_invitation_notification ON public.plan_invites;
CREATE TRIGGER trg_create_invitation_notification
  AFTER INSERT ON public.plan_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.create_invitation_notification();
