-- docs/supabase/audit_and_forecast_scaffold.sql
-- Safe-to-rerun scaffolding for audit logging and parking forecast readiness.

create extension if not exists pgcrypto;

-- 1) Audit log (append-only style)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  entity text not null,
  entity_id text not null,
  org_id uuid null,
  actor_user_id uuid null,
  diff jsonb null,
  ip inet null,
  ua text null,
  ts timestamptz not null default now(),
  signature text null -- optional tamper-evident HMAC signature
);
create index if not exists idx_audit_ts on public.audit_log(ts desc);
create index if not exists idx_audit_org on public.audit_log(org_id);
create index if not exists idx_audit_entity on public.audit_log(entity, entity_id);

-- Optional: simple RLS for reads by org; customize as needed.
alter table public.audit_log enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS audit_read_org ON public.audit_log;
  CREATE POLICY audit_read_org ON public.audit_log
  FOR SELECT TO authenticated
  USING (
    -- allow if org matches JWT claim when present; relax per your admin model
    coalesce((auth.jwt()->>'app_org_id')::uuid, org_id) = org_id OR (auth.jwt()->>'is_admin') = 'true'
  );
END $$;

-- 2) Parking forecast scaffolding
-- Daily model per POI (DoW x hour) + recency boost; basic shape only.
create table if not exists public.parking_forecast (
  poi_id uuid not null,
  dow smallint not null check (dow between 0 and 6), -- 0=Sun
  hour smallint not null check (hour between 0 and 23),
  p_open numeric(5,4) not null default 0.3333,
  p_some numeric(5,4) not null default 0.3333,
  p_full numeric(5,4) not null default 0.3333,
  eta_80pct interval null,
  updated_at timestamptz not null default now(),
  primary key (poi_id, dow, hour)
);
create index if not exists idx_parking_forecast_poi on public.parking_forecast(poi_id);

-- 3) Helper view (optional): best next-hour forecast for a poi
create or replace view public.parking_forecast_next as
select
  pf.poi_id,
  pf.dow,
  pf.hour,
  pf.p_open,
  pf.p_some,
  pf.p_full,
  pf.eta_80pct,
  pf.updated_at
from public.parking_forecast pf;

-- Notes:
-- - Edge Functions can write audit rows using supabase/functions/_shared/audit.ts helper.
-- - A nightly forecasting job can upsert into parking_forecast consuming audit/state data.
