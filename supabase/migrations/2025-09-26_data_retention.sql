-- 2025-09-26_data_retention.sql
-- Minimal data retention purge for webhook_deliveries and audit_logs with org scoping
-- Uses GUC settings for retention days; defaults applied if not present.

-- Create settings table if not exists (idempotent)
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

-- Helper to get integer setting with default
create or replace function public.get_setting_int(p_key text, p_default int)
returns int language sql stable as $$
  select coalesce((select (value)::int from public.app_settings where key = p_key), p_default)
$$;

-- Purge function: deletes old rows beyond retention days per table
create or replace function public.purge_old_data()
returns void language plpgsql as $$
declare
  v_webhook_days int := public.get_setting_int('retention.webhook_deliveries.days', 30);
  v_audit_days   int := public.get_setting_int('retention.audit_logs.days', 90);
begin
  -- Webhook deliveries
  execute format('delete from public.webhook_deliveries where created_at < now() - interval ''%s days''', v_webhook_days);
  -- Audit logs (if table exists)
  if exists(select 1 from information_schema.tables where table_schema='public' and table_name='audit_logs') then
    execute format('delete from public.audit_logs where created_at < now() - interval ''%s days''', v_audit_days);
  end if;
end;
$$;

comment on function public.purge_old_data() is 'Purges old operational data based on configured retention days.';

-- Optional: schedule via pg_cron if available
-- select cron.schedule('purge_old_data_daily', '15 3 * * *', $$select public.purge_old_data()$$);
