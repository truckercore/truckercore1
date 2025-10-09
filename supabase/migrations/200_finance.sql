-- Finance scaffolding
create table if not exists public.load_revenue (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  load_id uuid not null,
  amount_usd numeric(12,2) not null,
  created_at timestamptz not null default now(),
  unique(org_id, load_id)
);
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  category text not null check (category in ('fuel','tolls','repairs','tires','insurance','permits','parking','detention','lumper','other')),
  amount_usd numeric(12,2) not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_expenses_org_time on public.expenses(org_id, created_at desc);
alter table public.load_revenue enable row level security;
alter table public.expenses enable row level security;
create policy load_revenue_org_rw on public.load_revenue
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
create policy expenses_org_rw on public.expenses
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- ROI view
create or replace view public.load_profitability as
select
  r.org_id,
  r.load_id,
  r.amount_usd as revenue_usd,
  coalesce((
    select sum(amount_usd) from public.expenses e
    where e.org_id = r.org_id and (e.meta->>'load_id')::uuid = r.load_id
  ),0) as cost_usd,
  (r.amount_usd - coalesce((
    select sum(amount_usd) from public.expenses e
    where e.org_id = r.org_id and (e.meta->>'load_id')::uuid = r.load_id
  ),0)) as margin_usd
from public.load_revenue r;
grant select on public.load_profitability to authenticated;
