-- 002_helpers.sql

-- Sum usage helper for quotas
create or replace function public.sum_usage(p_org uuid, p_feature text)
returns numeric
language sql stable
as $$
  select coalesce(sum(qty),0)
  from public.feature_usage
  where org_id = p_org and feature = p_feature
$$;

-- Basic RLS for audit_log (read own org only; writes allowed via service role)
alter table if exists public.audit_log enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='audit_log' and policyname='tenant_audit_read'
  ) then
    create policy tenant_audit_read on public.audit_log
      for select
      to authenticated
      using (
        org_id is null
        or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      );
  end if;
end$$;

-- Optional: driver can insert own DVIR; dispatcher/admin can view all in org
alter table if exists public.dvir_reports enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='dvir_reports' and policyname='dvir_read_write'
  ) then
    create policy dvir_read_write on public.dvir_reports
      to authenticated
      using (
        org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      )
      with check (
        driver_id = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.id = auth.uid()
            and p.org_id = dvir_reports.org_id
            and p.role in ('dispatcher','admin')
        )
      );
  end if;
end$$;

-- Quality metrics: false positive rate from alert feedback stored in audit_log.meta
create or replace view public.v_alert_quality as
select
  date_trunc('day', created_at) as day,
  (meta->>'alertKind') as alert_kind,
  sum(case when meta->>'verdict' = 'false_positive' then 1 else 0 end)::float
  / nullif(count(*),0) as fp_rate
from public.audit_log
where action = 'alert_feedback'
group by 1,2;
