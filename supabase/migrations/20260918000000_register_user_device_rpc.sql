-- Same-device account switching: allow the currently authenticated user to
-- atomically CLAIM an FCM push token, even if the (globally unique) token is
-- still associated with a previously signed-in user on the same physical
-- device.
--
-- Why this is needed:
--   * public.user_devices.push_token is globally UNIQUE.
--   * RLS on user_devices only allows a user to INSERT/UPDATE/DELETE rows where
--     auth.uid() = user_id. When User A logs out and User B logs in on the same
--     device, FirebaseMessaging returns the SAME token T. A plain upsert on
--     conflict(push_token) becomes an UPDATE of A's row, which RLS blocks for B
--     (auth.uid() = B <> user_id = A) -> error 42501. The token can never move
--     from A to B, so B receives no notifications until the device is switched
--     back to A.
--
-- This SECURITY DEFINER function performs the move safely. It is strictly
-- scoped to auth.uid(): a caller can only ever associate a token with THEMSELF.
-- Because the token physically lives on the current device, re-homing it to the
-- current user is exactly the desired behaviour. Table RLS is left unchanged and
-- multi-device support is preserved (a user may hold many tokens; a token maps
-- to exactly one user -- the current holder).

create or replace function public.register_user_device(
  p_push_token text,
  p_platform text,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_platform text := p_platform;
begin
  -- Never register a token without an authenticated Supabase user.
  if v_uid is null then
    return;
  end if;

  if p_push_token is null or length(p_push_token) = 0 then
    return;
  end if;

  if v_platform is null or v_platform not in ('android', 'ios') then
    v_platform := 'android';
  end if;

  -- Claim the token: drop any stale association held by a DIFFERENT user on
  -- this same physical device. Rows owned by the current user are handled by
  -- the upsert below, so multi-device rows for OTHER tokens are untouched.
  delete from public.user_devices
  where push_token = p_push_token
    and user_id <> v_uid;

  insert into public.user_devices (user_id, push_token, platform, app_version, last_seen_at)
  values (v_uid, p_push_token, v_platform, p_app_version, now())
  on conflict (push_token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    last_seen_at = now();
end;
$$;

-- Only authenticated users may register a device; the function itself enforces
-- that the row is always owned by auth.uid().
revoke all on function public.register_user_device(text, text, text) from public;
grant execute on function public.register_user_device(text, text, text) to authenticated;
