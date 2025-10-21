-- docs/supabase/alerts.sql
-- Alert snooze, deduped deliveries, and MTTA/MTTR views. Idempotent.

create extension if not exists pgcrypto;

-- 1) Snooze table (Ack until) with RLS (per spec)
create table if not exists public.alert_snooze (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,                  -- e.g., 'SSO_FAIL_RATE', 'SCIM_PARTIAL'
  until_at timestamptz not null,      -- ignore alerts until this time
  reason text null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  unique (org_id, code)
);

create index if not exists idx_alert_snooze_org_code on public.alert_snooze (org_id, code);

alter table public.alert_snooze enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS alert_snooze_read_org ON public.alert_snooze;
  CREATE POLICY alert_snooze_read_org ON public.alert_snooze
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));

  DROP POLICY IF EXISTS alert_snooze_write_admin ON public.alert_snooze;
  CREATE POLICY alert_snooze_write_admin ON public.alert_snooze
  FOR INSERT TO authenticated
  WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id')
    AND (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
  );

  DROP POLICY IF EXISTS alert_snooze_update_admin ON public.alert_snooze;
  CREATE POLICY alert_snooze_update_admin ON public.alert_snooze
  FOR UPDATE TO authenticated
  USING (
    org_id::text = public.jwt_claim('app_org_id')
    AND (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
  )
  WITH CHECK (
    org_id::text = public.jwt_claim('app_org_id')
  );

  DROP POLICY IF EXISTS alert_snooze_delete_admin ON public.alert_snooze;
  CREATE POLICY alert_snooze_delete_admin ON public.alert_snooze
  FOR DELETE TO authenticated
  USING (
    org_id::text = public.jwt_claim('app_org_id')
    AND (coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'corp_admin')
  );
END $$;

-- 2) Deliveries: record per (org, code, window) with channels to deduplicate multi-channel notifications
create table if not exists public.alert_deliveries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  code text not null,
  severity text not null,
  window_start timestamptz not null,
  window_end timestamptz not null,
  channels jsonb not null default '[]'::jsonb,  -- e.g., ['pagerduty','slack','email']
  first_seen_at timestamptz not null default now(),
  last_sent_at timestamptz null,
  resolved_at timestamptz null,
  meta jsonb not null default '{}'::jsonb,
  unique (org_id, code, window_start, window_end)
);
create index if not exists idx_alert_deliveries_org_code on public.alert_deliveries(org_id, code);
create index if not exists idx_alert_deliveries_time on public.alert_deliveries(window_start, window_end);

alter table public.alert_deliveries enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS alert_deliveries_read_org ON public.alert_deliveries;
  CREATE POLICY alert_deliveries_read_org ON public.alert_deliveries
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- writes via service_role only
revoke insert, update, delete on public.alert_deliveries from authenticated;

-- 3) RPC: upsert and mark channel delivered or resolved; service-role only
create or replace function public.upsert_alert_delivery(
  p_org_id uuid,
  p_code text,
  p_severity text,
  p_window_start timestamptz,
  p_window_end timestamptz,
  p_channel text,
  p_meta jsonb default '{}'::jsonb,
  p_resolved boolean default false
) returns public.alert_deliveries
language plpgsql security definer
as $$
DECLARE
  v_row public.alert_deliveries;
  v_channels jsonb;
BEGIN
  -- Upsert the base row
  INSERT INTO public.alert_deliveries(org_id, code, severity, window_start, window_end, channels, meta, first_seen_at)
  VALUES (p_org_id, p_code, p_severity, p_window_start, p_window_end, '[]'::jsonb, coalesce(p_meta, '{}'::jsonb), now())
  ON CONFLICT (org_id, code, window_start, window_end) DO NOTHING;

  -- Fetch current row
  SELECT * INTO v_row FROM public.alert_deliveries WHERE org_id = p_org_id AND code = p_code AND window_start = p_window_start AND window_end = p_window_end;

  -- If resolving, mark resolved_at
  IF p_resolved THEN
    UPDATE public.alert_deliveries
    SET resolved_at = coalesce(resolved_at, now()), last_sent_at = now(), meta = coalesce(p_meta, meta)
    WHERE id = v_row.id
    RETURNING * INTO v_row;
    RETURN v_row;
  END IF;

  -- Append channel if not present
  v_channels := coalesce(v_row.channels, '[]'::jsonb);
  IF NOT (v_channels ? p_channel) THEN
    v_channels := v_channels || jsonb_build_array(p_channel);
    UPDATE public.alert_deliveries
    SET channels = v_channels, last_sent_at = now(), meta = coalesce(p_meta, meta)
    WHERE id = v_row.id
    RETURNING * INTO v_row;
  END IF;

  RETURN v_row;
END;
$$;

revoke all on function public.upsert_alert_delivery(uuid,text,text,timestamptz,timestamptz,text,jsonb,boolean) from public;
grant execute on function public.upsert_alert_delivery(uuid,text,text,timestamptz,timestamptz,text,jsonb,boolean) to service_role;

-- 4) Weekly MTTA/MTTR view (by org, code)
-- MTTA: time from first_seen_at to first snooze created after first_seen_at (within 7 days window)
-- MTTR: time from first_seen_at to resolved_at
create or replace view public.v_alert_mtta_mttr_week as
with firsts as (
  select org_id, code,
         date_trunc('week', first_seen_at) as week,
         min(first_seen_at) as first_seen
  from public.alert_deliveries
  where first_seen_at >= now() - interval '7 days'
  group by org_id, code, date_trunc('week', first_seen_at)
), acks as (
  select f.org_id, f.code, f.week,
         min(s.created_at) as first_ack
  from firsts f
  left join public.alert_snooze s
    on s.org_id = f.org_id and s.code = f.code and s.created_at >= f.first_seen
  group by f.org_id, f.code, f.week
), res as (
  select org_id, code, date_trunc('week', first_seen_at) as week,
         min(resolved_at) as first_resolved
  from public.alert_deliveries
  where resolved_at is not null and resolved_at >= now() - interval '7 days'
  group by org_id, code, date_trunc('week', first_seen_at)
)
select f.org_id, f.code, f.week,
       extract(epoch from (a.first_ack - f.first_seen))/60.0 as mtta_minutes,
       extract(epoch from (r.first_resolved - f.first_seen))/60.0 as mttr_minutes
from firsts f
left join acks a on a.org_id = f.org_id and a.code = f.code and a.week = f.week
left join res r on r.org_id = f.org_id and r.code = f.code and r.week = f.week;
