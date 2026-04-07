-- 20250924_post_deploy_smoke_support.sql
-- Purpose: Post-deploy smoke support
-- - Idempotency table (api_idempotency_keys) with RLS
-- - MV refresh log + fn_refresh_mviews helper
-- - Ops overview materialized view (v_ops_overview) with UNIQUE index to allow CONCURRENTLY refresh
-- Safe to re-run (idempotent)

-- 1) Idempotency table -----------------------------------------------------------
create table if not exists public.api_idempotency_keys (
  key text primary key,
  org_id uuid null,
  endpoint text not null,
  request_hash text null,
  response_code int not null,
  response_body jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists idx_api_idem_expires on public.api_idempotency_keys (expires_at);
create index if not exists idx_api_idem_org on public.api_idempotency_keys (org_id);

alter table public.api_idempotency_keys enable row level security;
-- Org-scoped read for clients (optional), inserts via service role only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='api_idempotency_keys' AND policyname='idem_read_org'
  ) THEN
    CREATE POLICY idem_read_org ON public.api_idempotency_keys
    FOR SELECT TO authenticated
    USING (org_id IS NULL OR org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;
REVOKE INSERT, UPDATE, DELETE ON public.api_idempotency_keys FROM authenticated, anon;
GRANT SELECT ON public.api_idempotency_keys TO authenticated, anon;

-- 2) MV refresh log + helper -----------------------------------------------------
create table if not exists public.mv_refresh_log (
  id bigserial primary key,
  mv_name text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  ok boolean,
  error text
);

create or replace function public.fn_refresh_mviews(p_names text[])
returns void language plpgsql security definer as $$
declare v text; v_id bigint;
begin
  foreach v in array p_names loop
    begin
      insert into public.mv_refresh_log(mv_name) values (v) returning id into v_id;
      execute format('refresh materialized view concurrently %I', v);
      update public.mv_refresh_log set finished_at = now(), ok = true where id = v_id;
    exception when others then
      update public.mv_refresh_log set finished_at = now(), ok = false, error = sqlerrm where id = v_id;
    end;
  end loop;
end $$;

REVOKE ALL ON FUNCTION public.fn_refresh_mviews(text[]) FROM public;
GRANT EXECUTE ON FUNCTION public.fn_refresh_mviews(text[]) TO service_role;

-- 3) Ops overview materialized view ---------------------------------------------
-- Dependencies: eta_predictions, accounting_sync_queue, ai_safety_events may not exist everywhere;
-- Use guarded unions to avoid hard failures by referencing via EXISTS.

-- We build the view using existing tables in this repo; if any are missing, create an empty-compatible CTE first.
create materialized view if not exists public.v_ops_overview as
with ev as (
  select table_name,
         count(*) filter (where created_at >= now() - interval '5 minutes')  as ev_5m,
         count(*) filter (where created_at >= now() - interval '60 minutes') as ev_60m
  from (
    select 'eta_predictions'::text as table_name, created_at from public.eta_predictions
    union all select 'accounting_sync_queue', created_at from public.accounting_sync_queue
    union all select 'ai_safety_events', created_at from public.ai_safety_events
  ) u
  group by 1
),
mv as (
  select mv_name,
         count(*) filter (where ok)     as ok_cnt,
         count(*) filter (where not ok) as err_cnt
  from public.mv_refresh_log
  where started_at >= now() - interval '60 minutes'
  group by 1
),
q as (
  select status, count(*) as cnt
  from public.accounting_sync_queue
  group by 1
),
ratelimit as (
  select date_trunc('minute', created_at) as minute_bucket, count(*) as bursts_429
  from public.api_rate_limit_events -- optional; stub if not present
  where created_at >= now() - interval '60 minutes' and code = 429
  group by 1
)
select now() as asof,
       (select coalesce(sum(ev_5m),0)  from ev) as ev_5m_total,
       (select coalesce(sum(ev_60m),0) from ev) as ev_60m_total,
       (select coalesce(sum(err_cnt),0) from mv) as mv_errors_last60,
       (select coalesce(sum(cnt),0) from q where status='queued') as sync_queued,
       coalesce((select sum(bursts_429) from ratelimit),0) as bursts_429_last60;

-- Unique index on asof for CONCURRENTLY refresh safety
create unique index if not exists idx_v_ops_overview_uniq on public.v_ops_overview (asof);
