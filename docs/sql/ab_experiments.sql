-- =============================================================
-- A/B Experiments (server-driven) + Assignments + Exposures
-- Results views and KPIs. Idempotent and safe to re-run.
-- =============================================================

-- 1) Define experiments
create table if not exists public.ab_experiments (
  key text primary key,                  -- e.g., 'upsell_copy_ai_capacity'
  feature_key text not null,            -- links to your feature_catalog.key
  env text not null default 'prod',     -- 'prod'|'staging'|'dev'
  start_at timestamptz not null default now(),
  end_at   timestamptz,                 -- null = open
  weights jsonb not null,               -- {"A":0.5,"B":0.5}
  status text not null default 'active' -- 'active'|'paused'|'archived'
);

-- 2) Sticky assignment store (org and/or user)
create table if not exists public.ab_assignments (
  org_id uuid not null,
  user_id uuid,
  exp_key text not null references public.ab_experiments(key) on delete cascade,
  variant text not null,                -- 'A'|'B'|...
  assigned_at timestamptz default now(),
  primary key (org_id, coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), exp_key)
);

-- 3) Exposure + outcome logging (append-only)
create table if not exists public.ab_exposures (
  id uuid primary key default gen_random_uuid(),
  exp_key text not null,
  org_id uuid not null,
  user_id uuid,
  variant text not null,
  event text not null,                  -- 'view'|'click'|'checkout_open'|'checkout_success'
  request_id text,
  at timestamptz default now(),
  meta jsonb
);

-- RLS policies (read open, write controlled)
alter table public.ab_experiments  enable row level security;
alter table public.ab_assignments  enable row level security;
alter table public.ab_exposures    enable row level security;

-- Everyone (authenticated) can read experiments
do $$ begin
  create policy ab_public_ro on public.ab_experiments for select to authenticated using (true);
exception when duplicate_object then null; end $$;

-- Read assignments (for debugging/admin clients)
do $$ begin
  create policy ab_assign_ro on public.ab_assignments for select to authenticated using (true);
exception when duplicate_object then null; end $$;

-- Writes via service role only for assignments
-- (Supabase maps service-key to role "service_role")
do $$ begin
  create policy ab_assign_wr on public.ab_assignments for insert to service_role with check (true);
exception when duplicate_object then null; end $$;

-- Exposures: allow anon/auth to write (can tighten later)
do $$ begin
  create policy ab_expos_ro on public.ab_exposures for select to authenticated using (true);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy ab_expos_w on public.ab_exposures for insert to authenticated, anon with check (true);
exception when duplicate_object then null; end $$;

-- 4) Results rollup (CTR & conversion)
create or replace view public.v_ab_results as
with base as (
  select exp_key, variant,
         count(*) filter (where event='view')             as views,
         count(*) filter (where event='click')            as clicks,
         count(*) filter (where event='checkout_open')    as opens,
         count(*) filter (where event='checkout_success') as converts
  from public.ab_exposures
  where at > now() - interval '30 days'
  group by 1,2
)
select *,
  (case when views>0 then clicks::numeric/views  else 0 end) as ctr,
  (case when opens>0 then converts::numeric/opens else 0 end) as checkout_conv,
  (case when views>0 then converts::numeric/views else 0 end) as end_to_end_conv
from base;

-- 5) Exec-ready KPIs
create or replace view public.v_ab_kpis as
select
  (select count(*) from public.ab_experiments where status='active') as active_experiments,
  (select coalesce(sum(converts),0) from public.v_ab_results)        as converts_30d,
  (select variant from public.v_ab_results order by end_to_end_conv desc nulls last limit 1) as top_variant_30d;

-- 6) Optional guardrail: weights must sum ~1 (use from CI script)
-- Example query:
-- select key from public.ab_experiments where abs((select sum((v)::numeric) from jsonb_each_text(weights)) - 1) > 0.0001;
