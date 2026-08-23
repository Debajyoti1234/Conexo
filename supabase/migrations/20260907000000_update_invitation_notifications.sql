-- P1.2B.11C: Update invitation notification text + accepted notification
--
-- Replaces the invitation notification trigger and accept RPC to include
-- the host display name and create an accepted notification.

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
