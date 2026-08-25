-- Web FCM support: allow platform = 'web' for browser push tokens.
--
-- user_devices previously constrained platform to ('android','ios'), and
-- register_user_device() coerced any unknown platform to 'android'. Both are
-- updated to accept 'web' so the SAME token-claim architecture used by Android
-- also stores web browser tokens (a user may hold android/ios/web tokens at
-- once). No other behaviour changes; RLS and the claim semantics are identical.

alter table public.user_devices
  drop constraint if exists user_devices_platform_check;

alter table public.user_devices
  add constraint user_devices_platform_check
  check (platform = any (array['android'::text, 'ios'::text, 'web'::text]));

-- Re-declare the claim RPC so 'web' is a first-class platform (previously it was
-- silently rewritten to 'android'). Everything else is unchanged: SECURITY
-- DEFINER, strictly scoped to auth.uid(), claims the (globally unique) token
-- for the current user, preserves multi-device.
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
  if v_uid is null then
    return;
  end if;

  if p_push_token is null or length(p_push_token) = 0 then
    return;
  end if;

  if v_platform is null or v_platform not in ('android', 'ios', 'web') then
    v_platform := 'android';
  end if;

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

revoke all on function public.register_user_device(text, text, text) from public;
grant execute on function public.register_user_device(text, text, text) to authenticated;
