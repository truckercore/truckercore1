create table if not exists public.org_rate_limiter(
  org_id uuid primary key,
  tokens int not null default 60,
  refreshed_at timestamptz not null default now()
);

create or replace function public.take_token(p_org_id uuid, p_capacity int default 60, p_refill int default 60)
returns boolean language plpgsql as $$
declare
  nowts timestamptz := now();
  elapsed_min double precision;
begin
  insert into public.org_rate_limiter(org_id, tokens, refreshed_at)
  values (p_org_id, p_capacity-1, nowts)
  on conflict (org_id) do update set
    tokens = greatest(0, least(p_capacity,
      public.org_rate_limiter.tokens
      + floor(extract(epoch from (nowts - public.org_rate_limiter.refreshed_at))/60.0)*p_refill) - 1),
    refreshed_at = nowts;
  return (select tokens >= 0 from public.org_rate_limiter where org_id = p_org_id);
end $$;

revoke all on function public.take_token(uuid,int,int) from public;
grant execute on function public.take_token(uuid,int,int) to authenticated, service_role;
