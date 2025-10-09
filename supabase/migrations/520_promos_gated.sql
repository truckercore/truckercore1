-- Safety feed (public-readable, no PII)
create table if not exists public.safety_feed (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  state text,
  message text not null,
  reported_by uuid,
  reported_at timestamptz not null default now()
);
alter table public.safety_feed enable row level security;
create policy safety_feed_public_read on public.safety_feed for select using (true);
create policy safety_feed_insert_auth on public.safety_feed for insert to authenticated with check (true);

-- Gated promos view (hide when not premium)
create or replace view public.v_promos_gated as
select *
from public.discounts_promos
where (min_tier = 'free') or
      (coalesce(current_setting('request.jwt.claims', true)::json->>'app_is_premium','false')::boolean);
grant select on public.v_promos_gated to authenticated;
