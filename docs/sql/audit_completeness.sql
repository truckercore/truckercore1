-- docs/sql/audit_completeness.sql
-- Safe-to-rerun objects for audit completeness KPIs and gap detection

-- View: audit completeness over last 24h using pg_stat_all_tables and audit_log
create or replace view public.v_audit_completeness as
select
  stats.relname as table_name,
  coalesce(audit.count_rows,0) as audited_events,
  coalesce(stats.n_mods,0) as modifications,
  (coalesce(audit.count_rows,0) = coalesce(stats.n_mods,0)) as complete
from (
  select relname, (n_tup_ins + n_tup_upd + n_tup_del) as n_mods
  from pg_stat_all_tables
  where schemaname = 'public'
) stats
left join (
  select tableoid::regclass::text as relname, count(*) as count_rows
  from public.audit_log
  where created_at > now() - interval '1 day'
  group by tableoid
) audit
on audit.relname = stats.relname;

-- Function: insert warning alerts when audit is incomplete
create or replace function public.fn_audit_gap_detect()
returns void language plpgsql security definer
set search_path=public
as $$
declare r record;
begin
  for r in
    select * from public.v_audit_completeness
    where complete = false and modifications > 0
  loop
    insert into public.alerts_events(org_id, severity, code, payload)
    values (null, 'warning', 'AUDIT_GAP', jsonb_build_object(
      'table', r.table_name,
      'audited_events', r.audited_events,
      'modifications', r.modifications
    ));
  end loop;
end $$;

-- View: single-number board metric (capture rate)
create or replace view public.v_audit_capture_rate as
select
  case when sum(modifications) = 0 then 1.0::numeric
       else sum(audited_events)::numeric / nullif(sum(modifications),0) end as capture_rate
from public.v_audit_completeness;
