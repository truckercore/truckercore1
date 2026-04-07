-- docs/supabase/acceptance_registry_versioned.sql
-- Versioned Acceptance Registry with snapshots, results, pass-rate views, and helper RPCs.
-- Idempotent. Safe to re-run.

create extension if not exists pgcrypto;

-- 1) Registry of checklist items (versioned)
create table if not exists public.acceptance_registry (
  id uuid primary key default gen_random_uuid(),
  registry_version int not null,
  code text not null,
  title text not null,
  description text not null,
  required boolean not null default true,
  category text not null,
  created_at timestamptz not null default now(),
  unique (registry_version, code)
);

-- 2) Snapshot of "expected" registry at a point in time (for traceability)
create table if not exists public.acceptance_registry_snapshots (
  snapshot_id uuid primary key default gen_random_uuid(),
  registry_version int not null,
  applied_at timestamptz not null default now()
);

-- 3) Expected items captured into snapshot (denormalized copy for stability)
create table if not exists public.acceptance_registry_snapshot_items (
  snapshot_id uuid not null references public.acceptance_registry_snapshots(snapshot_id) on delete cascade,
  code text not null,
  title text not null,
  required boolean not null,
  category text not null,
  primary key (snapshot_id, code)
);

-- 4) Actual results per org (what was checked and status at time T)
create table if not exists public.acceptance_results (
  org_id uuid not null,
  snapshot_id uuid not null references public.acceptance_registry_snapshots(snapshot_id) on delete restrict,
  code text not null,
  status text not null check (status in ('pass','fail','n/a','pending')),
  notes text null,
  checked_at timestamptz not null default now(),
  checked_by uuid null,
  primary key (org_id, snapshot_id, code)
);

-- 5) Convenience view to compute pass rate required vs optional
create or replace view public.v_acceptance_pass_rates as
select
  ar.org_id,
  ar.snapshot_id,
  s.registry_version,
  count(*) filter (where i.required) as required_total,
  count(*) filter (where not i.required) as optional_total,
  count(*) filter (where i.required and ar.status = 'pass') as required_pass,
  count(*) filter (where not i.required and ar.status = 'pass') as optional_pass,
  case when count(*) filter (where i.required) = 0 then 1.0
       else (count(*) filter (where i.required and ar.status = 'pass')::numeric
            / nullif(count(*) filter (where i.required),0)) end as required_pass_rate,
  case when count(*) filter (where not i.required) = 0 then null
       else (count(*) filter (where not i.required and ar.status = 'pass')::numeric
            / nullif(count(*) filter (where not i.required),0)) end as optional_pass_rate
from public.acceptance_results ar
join public.acceptance_registry_snapshot_items i
  on i.snapshot_id = ar.snapshot_id and i.code = ar.code
join public.acceptance_registry_snapshots s
  on s.snapshot_id = ar.snapshot_id
group by ar.org_id, ar.snapshot_id, s.registry_version;

-- 6) RLS (read to org; writes via service/admin tooling)
alter table public.acceptance_registry enable row level security;
alter table public.acceptance_registry_snapshots enable row level security;
alter table public.acceptance_registry_snapshot_items enable row level security;
alter table public.acceptance_results enable row level security;

-- Read: any authenticated can read snapshots and items; scope results by org
DO $$ BEGIN
  DROP POLICY IF EXISTS ars_read_all ON public.acceptance_registry_snapshots;
  CREATE POLICY ars_read_all ON public.acceptance_registry_snapshots FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS arsi_read_all ON public.acceptance_registry_snapshot_items;
  CREATE POLICY arsi_read_all ON public.acceptance_registry_snapshot_items FOR SELECT TO authenticated USING (true);
END $$;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS ar_read_org ON public.acceptance_results;
  CREATE POLICY ar_read_org ON public.acceptance_results
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- Writes: service/admin only (adjust if you allow org admins to update their results)
REVOKE INSERT, UPDATE, DELETE ON public.acceptance_results FROM authenticated;

-- Helper: create a snapshot from current registry version
create or replace function public.fn_acceptance_snapshot_create(p_registry_version int)
returns uuid
language plpgsql
security definer
as $$
declare v_snapshot uuid;
begin
  insert into public.acceptance_registry_snapshots (registry_version)
  values (p_registry_version) returning snapshot_id into v_snapshot;

  insert into public.acceptance_registry_snapshot_items (snapshot_id, code, title, required, category)
  select v_snapshot, code, title, required, category
  from public.acceptance_registry
  where registry_version = p_registry_version;

  return v_snapshot;
end $$;

revoke all on function public.fn_acceptance_snapshot_create(int) from public;
grant execute on function public.fn_acceptance_snapshot_create(int) to service_role;

-- View to select the latest snapshot per org with pass rates
create or replace view public.v_acceptance_latest as
select distinct on (org_id)
  org_id, snapshot_id, registry_version, required_pass_rate, optional_pass_rate
from public.v_acceptance_pass_rates
order by org_id, snapshot_id desc;

-- Optional: RPC to compute pass rate and return snapshot (for API)
create or replace function public.fn_acceptance_status(p_org_id uuid)
returns jsonb
language sql
security definer
as $$
  with latest as (
    select snapshot_id
    from public.acceptance_results
    where org_id = p_org_id
    order by snapshot_id desc
    limit 1
  )
  select jsonb_build_object(
    'org_id', p_org_id,
    'snapshot_id', (select snapshot_id from latest),
    'rates', (
      select to_jsonb(v) from public.v_acceptance_pass_rates v
      where v.org_id = p_org_id and v.snapshot_id = (select snapshot_id from latest)
    )
  )
$$;

revoke all on function public.fn_acceptance_status(uuid) from public;
grant execute on function public.fn_acceptance_status(uuid) to authenticated, service_role;
