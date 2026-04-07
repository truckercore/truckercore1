-- docs/sql/circuit_autoheal.sql
create table if not exists public.circuit_breaker_events(
  id bigserial primary key,
  service text not null,
  from_state text not null,
  to_state text not null,
  at timestamptz default now()
);

-- Ensure base table exists
create table if not exists public.circuit_breakers(
  service text primary key,
  state text not null default 'closed',
  updated_at timestamptz not null default now()
);

create or replace function public.circuit_set_state(p_service text, p_to text)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare prev text;
begin
  select state into prev from public.circuit_breakers where service=p_service;
  insert into public.circuit_breakers(service, state, updated_at)
  values (p_service, p_to, now())
  on conflict (service) do update set state=excluded.state, updated_at=excluded.updated_at;

  insert into public.circuit_breaker_events(service, from_state, to_state)
  values (p_service, coalesce(prev,'unknown'), p_to);
end $$;

create or replace function public.circuit_autoheal(p_minutes int default 30)
returns int
language plpgsql
security definer
set search_path=public
as $$
declare c int;
begin
  update public.circuit_breakers
     set state='closed', updated_at=now()
   where state='open' and updated_at < now() - make_interval(mins => p_minutes);
  GET DIAGNOSTICS c = ROW_COUNT;
  return c;
end $$;

-- breaker metrics view
create or replace view public.v_breaker_metrics as
select service,
       count(*) filter (where to_state='open')   as opens,
       count(*) filter (where to_state='closed') as closes,
       max(at)                                   as last_flip
from public.circuit_breaker_events
where at > now() - interval '24h'
group by service;
