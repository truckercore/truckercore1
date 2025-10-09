-- 992_rate_limit.sql
create table if not exists public.rate_limit_events (
  id bigserial primary key,
  actor uuid not null,
  key text not null,
  at timestamptz not null default now()
);

create index if not exists idx_rle_actor_time on public.rate_limit_events(actor, at);

create or replace function public.rate_limited(actor uuid, key text, max_calls int, window_secs int)
returns boolean
language sql
stable
set search_path = public
as $$
  select (
    select count(*)
    from public.rate_limit_events
    where actor = $1
      and key = $2
      and at >= now() - make_interval(secs => $4)
  ) < $3;
$$;

create or replace function public.rate_limit_touch(actor uuid, key text)
returns void
language sql
volatile
set search_path = public
as $$
  insert into public.rate_limit_events(actor, key) values ($1, $2);
$$;
