-- docs/supabase/sso_alert_thresholds.sql
-- Add alert threshold support and views for SSO/SCIM health. Idempotent.

create extension if not exists pgcrypto;

-- 1) Add canary_consecutive_failures to sso_health if missing
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='sso_health' AND column_name='canary_consecutive_failures'
  ) THEN
    EXECUTE 'ALTER TABLE public.sso_health ADD COLUMN canary_consecutive_failures int not null default 0';
  END IF;
END $$;

-- 2) Replace helper functions to update consecutive failures and 24h counters
create or replace function public.fn_sso_mark_success(p_org_id uuid, p_idp text)
returns void language plpgsql security definer as $$
BEGIN
  INSERT INTO public.sso_health(org_id, last_success_at, idp, attempts_24h, failures_24h, updated_at, self_check_ok, canary_consecutive_failures)
  VALUES (p_org_id, now(), p_idp, 1, 0, now(), true, 0)
  ON CONFLICT (org_id) DO UPDATE
  SET last_success_at = excluded.last_success_at,
      idp = excluded.idp,
      attempts_24h = public.sso_health.attempts_24h + 1,
      -- do not increment failures on success
      updated_at = now(),
      self_check_ok = true,
      canary_consecutive_failures = 0;
END; $$;

create or replace function public.fn_sso_mark_error(p_org_id uuid, p_idp text, p_code text)
returns void language plpgsql security definer as $$
BEGIN
  INSERT INTO public.sso_health(org_id, last_error_at, last_error_code, idp, attempts_24h, failures_24h, updated_at, self_check_ok, canary_consecutive_failures)
  VALUES (p_org_id, now(), p_code, p_idp, 1, 1, now(), false, 1)
  ON CONFLICT (org_id) DO UPDATE
  SET last_error_at = excluded.last_error_at,
      last_error_code = excluded.last_error_code,
      idp = excluded.idp,
      attempts_24h = public.sso_health.attempts_24h + 1,
      failures_24h = public.sso_health.failures_24h + 1,
      updated_at = now(),
      self_check_ok = false,
      canary_consecutive_failures = public.sso_health.canary_consecutive_failures + 1;
END; $$;

revoke all on function public.fn_sso_mark_success(uuid,text) from public;
revoke all on function public.fn_sso_mark_error(uuid,text,text) from public;
grant execute on function public.fn_sso_mark_success(uuid,text) to service_role;
grant execute on function public.fn_sso_mark_error(uuid,text,text) to service_role;

-- 3) Optional: track self-check 429s to detect abuse spikes
create table if not exists public.sso_selfcheck_events (
  id bigserial primary key,
  org_id uuid not null,
  status text not null check (status in ('ok','429','error')),
  ts timestamptz not null default now()
);
create index if not exists idx_selfcheck_events_org_ts on public.sso_selfcheck_events(org_id, ts desc);

alter table public.sso_selfcheck_events enable row level security;
DO $$ BEGIN
  DROP POLICY IF EXISTS selfcheck_read ON public.sso_selfcheck_events;
  CREATE POLICY selfcheck_read ON public.sso_selfcheck_events FOR SELECT TO authenticated USING (
    org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  );
END $$;

-- 4) Views for alerts
create or replace view public.v_sso_failure_rate_24h as
select org_id,
       case when attempts_24h <= 0 then null else (failures_24h::numeric / nullif(attempts_24h,0)) end as failure_rate_24h,
       attempts_24h, failures_24h,
       last_success_at, last_error_at, last_error_code,
       canary_consecutive_failures,
       idp,
       updated_at
from public.sso_health;

create or replace view public.v_selfcheck_429_15m as
select org_id, count(*) as cnt_429, min(ts) as window_start, max(ts) as window_end
from public.sso_selfcheck_events
where status = '429' and ts >= now() - interval '15 minutes'
group by org_id;

-- 5) RPC to mark self-check events (service role)
create or replace function public.fn_selfcheck_mark(p_org_id uuid, p_status text)
returns void language plpgsql security definer as $$
DECLARE
  v_status text := lower(p_status);
BEGIN
  IF v_status not in ('ok','429','error') THEN
    v_status := 'error';
  END IF;
  INSERT INTO public.sso_selfcheck_events(org_id, status)
  VALUES (p_org_id, v_status);
END; $$;

revoke all on function public.fn_selfcheck_mark(uuid,text) from public;
grant execute on function public.fn_selfcheck_mark(uuid,text) to service_role;
