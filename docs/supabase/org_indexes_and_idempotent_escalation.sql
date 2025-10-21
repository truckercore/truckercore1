-- Org-scoped indexes and idempotent escalation insert RPC
-- Apply in Supabase SQL editor or via CLI. Safe to run multiple times.

-- Alerts and escalations
create index if not exists idx_alerts_org_time on public.alerts_events (org_id, triggered_at desc);
create index if not exists idx_escalations_org_time on public.escalation_logs (org_id, created_at desc);

-- Retests and remediations
create index if not exists idx_retests_org_time on public.retest_runs (org_id, created_at desc);
create index if not exists idx_remediation_clicks_org_time on public.remediation_clicks (org_id, clicked_at desc);

-- SSO/SCIM health
create index if not exists idx_sso_health_org on public.sso_health (org_id);
create index if not exists idx_scim_audit_org_time on public.scim_audit (org_id, run_started_at desc);

-- Metrics/Events (optional, if used)
create index if not exists idx_metrics_kind_org_time on public.metrics_events (kind, created_at desc);

-- Weekly views/materializations often benefit from org/date
create index if not exists idx_analytics_org_date on public.analytics_snapshots (org_id, date_bucket desc);


-- Idempotent insert RPC for escalation_logs ---------------------------------
-- Schema additions if needed
alter table public.escalation_logs
  add column if not exists idempotency_key text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists code text,
  add column if not exists severity text,
  add column if not exists message text;

create unique index if not exists ux_escalations_org_idem
  on public.escalation_logs (org_id, idempotency_key)
  where idempotency_key is not null;

-- RLS (tenant write)
drop policy if exists escalation_org_insert on public.escalation_logs;
create policy escalation_org_insert on public.escalation_logs
for insert to authenticated
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- RPC: inserts once per (org_id, idempotency_key), returns existing row if duplicate
create or replace function public.fn_escalation_insert_idempotent(
  p_org_id uuid,
  p_code text,
  p_severity text,
  p_message text,
  p_idempotency_key text default null
) returns public.escalation_logs
language plpgsql
security definer
as $$
declare
  v_row public.escalation_logs;
begin
  if p_idempotency_key is not null then
    select * into v_row
    from public.escalation_logs
    where org_id = p_org_id and idempotency_key = p_idempotency_key
    limit 1;

    if found then
      return v_row;
    end if;
  end if;

  insert into public.escalation_logs (org_id, code, severity, message, idempotency_key)
  values (p_org_id, p_code, p_severity, p_message, p_idempotency_key)
  returning * into v_row;

  return v_row;
end $$;

revoke all on function public.fn_escalation_insert_idempotent(uuid,text,text,text,text) from public;
grant execute on function public.fn_escalation_insert_idempotent(uuid,text,text,text,text) to authenticated, service_role;
