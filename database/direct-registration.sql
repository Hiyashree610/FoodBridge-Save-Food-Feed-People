-- Apply after database/foodbridge.sql on a fresh Supabase database.
create table fb_private.signup_limits (
  key text primary key,
  window_start timestamptz not null default now(),
  attempts integer not null default 1
);
alter table fb_private.signup_limits enable row level security;
grant usage on schema fb_private to service_role;
grant select,insert,update on fb_private.signup_limits to service_role;
create function public.fb_signup_allowed(p_key text,p_limit integer)
returns boolean language sql security invoker set search_path='' as $$
insert into fb_private.signup_limits(key) values(p_key)
on conflict(key) do update set
  attempts=case when fb_private.signup_limits.window_start<now()-interval '15 minutes' then 1 else fb_private.signup_limits.attempts+1 end,
  window_start=case when fb_private.signup_limits.window_start<now()-interval '15 minutes' then now() else fb_private.signup_limits.window_start end
returning attempts<=p_limit
$$;
revoke all on function public.fb_signup_allowed(text,integer) from public,anon,authenticated;
grant execute on function public.fb_signup_allowed(text,integer) to service_role;
