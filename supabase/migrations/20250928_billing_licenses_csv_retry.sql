-- 20250928_billing_licenses_csv_retry.sql
-- Schemas assumed: public; auth.users for user ids.

-- 1) Core tables --------------------------------------------------------------

create table if not exists public.org_license_events (
  id bigserial primary key,
  org_id uuid not null,
  source text not null,        -- 'stripe' | 'manual' | 'ops'
  action text not null,        -- 'activate' | 'deactivate' | 'update'
  meta jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists org_license_events_org_created_idx
  on public.org_license_events (org_id, created_at desc);

create table if not exists public.csv_ingest_usage (
  id bigserial primary key,
  org_id uuid not null,
  bytes_ingested bigint not null,
  file_name text,
  occurred_at timestamptz not null default now()
);
create index if not exists csv_ingest_usage_org_time_idx
  on public.csv_ingest_usage (org_id, occurred_at desc);

create table if not exists public.webhook_retry (
  id bigserial primary key,
  provider text not null,         -- 'stripe' | 'internal' | 'other'
  event_id text not null,
  status text not null,           -- 'ok' | 'queued' | 'err'
  attempt int not null default 0,
  next_run_at timestamptz not null default now(),
  last_error text,
  payload jsonb,
  created_at timestamptz not null default now()
);
create unique index if not exists webhook_retry_provider_event_uidx
  on public.webhook_retry (provider, event_id);

-- 2) Optional orgs plan view (adjust orgs fields to match your orgs table)
-- Expect orgs(id uuid pk, name text, plan text, app_is_premium bool, license_status text)
create or replace view public.orgs_plan_view as
select
  o.id as org_id,
  o.name,
  coalesce(o.plan, 'free') as plan,
  coalesce(o.app_is_premium, false) as is_premium,
  coalesce(o.license_status, case when coalesce(o.app_is_premium,false) then 'active' else 'inactive' end) as license_status,
  (
    select ole.created_at
    from public.org_license_events ole
    where ole.org_id = o.id
    order by ole.created_at desc
    limit 1
  ) as last_license_event_at
from public.orgs o;

-- 3) CSV quota RPC ------------------------------------------------------------
-- Implemented defensively to support either bytes_ingested (this migration)
-- or bytes (existing schemas) without breaking.
create or replace function public.sum_csv_usage_24h(p_org uuid)
returns bigint
language plpgsql
stable
as $$
declare
  v bigint := 0;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='csv_ingest_usage' and column_name='bytes_ingested'
  ) then
    select coalesce(sum(bytes_ingested),0)::bigint into v
    from public.csv_ingest_usage
    where org_id = p_org and occurred_at >= now() - interval '24 hours';
  elsif exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='csv_ingest_usage' and column_name='bytes'
  ) then
    select coalesce(sum(bytes),0)::bigint into v
    from public.csv_ingest_usage
    where org_id = p_org and occurred_at >= now() - interval '24 hours';
  else
    v := 0;
  end if;
  return v;
end
$$;

grant execute on function public.sum_csv_usage_24h(uuid) to anon, authenticated, service_role;

-- 4) RLS & grants (secure by default) ----------------------------------------
alter table public.org_license_events enable row level security;
alter table public.csv_ingest_usage enable row level security;
alter table public.webhook_retry enable row level security;

-- Base: block all to start
revoke all on table public.org_license_events from anon, authenticated;
revoke all on table public.csv_ingest_usage from anon, authenticated;
revoke all on table public.webhook_retry from anon, authenticated;

-- Service role can do anything (grants)
grant select, insert, update, delete on table public.org_license_events to service_role;
grant select, insert, update, delete on table public.csv_ingest_usage to service_role;
grant select, insert, update, delete on table public.webhook_retry to service_role;

-- Policies (adjust your memberships/user_roles if present)
-- Admins can read org_license_events
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='org_license_events' AND polname='ole_admin_read'
  ) THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='user_roles') THEN
      CREATE POLICY ole_admin_read
      ON public.org_license_events
      FOR SELECT
      TO authenticated
      USING (
        exists (
          select 1 from public.user_roles ur
          where ur.user_id = auth.uid() and ur.role = 'admin'
        )
      );
    ELSE
      -- Fallback: no user_roles table; keep restricted (no policy created)
    END IF;
  END IF;
END $$;

-- csv_ingest_usage: org-limited read for authenticated users via memberships table; service writes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='csv_ingest_usage' AND polname='csv_org_read'
  ) THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='memberships') THEN
      CREATE POLICY csv_org_read
      ON public.csv_ingest_usage
      FOR SELECT
      TO authenticated
      USING (
        exists(
          select 1 from public.memberships m
          where m.user_id = auth.uid() and m.org_id = csv_ingest_usage.org_id
        )
      );
    ELSE
      -- Fallback: if org_memberships exists, use it instead
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='org_memberships') THEN
        CREATE POLICY csv_org_read
        ON public.csv_ingest_usage
        FOR SELECT
        TO authenticated
        USING (
          exists(
            select 1 from public.org_memberships m
            where m.user_id = auth.uid() and m.org_id = csv_ingest_usage.org_id
          )
        );
      END IF;
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='csv_ingest_usage' AND polname='csv_service_write'
  ) THEN
    CREATE POLICY csv_service_write
    ON public.csv_ingest_usage
    FOR INSERT
    TO service_role
    WITH CHECK (true);
  END IF;
END $$;

-- webhook_retry: service-only full access
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='webhook_retry' AND polname='wr_service_rw'
  ) THEN
    CREATE POLICY wr_service_rw
    ON public.webhook_retry
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;

-- 5) Optional: map/heat layers helper view -----------------------------------
-- Expose GeoJSON for corridor cells if present
create or replace view public.v_risk_corridors as
select
  id,
  org_id,
  alert_count,
  urgent_count,
  types,
  (st_asgeojson(cell)::json) as cell_geojson
from public.risk_corridor_cells;

grant select on public.v_risk_corridors to anon, authenticated, service_role;
