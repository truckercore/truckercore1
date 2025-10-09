create or replace function public.ensure_org_metrics_freshness()
returns void language plpgsql security definer set search_path=public as $$
declare
  missing int;
begin
  -- Yesterday (UTC) must exist for each org that had activity yesterday
  with candidates as (
    select distinct p.org_id
    from public.profiles p
  ), missing_orgs as (
    select c.org_id
    from candidates c
    left join public.org_metrics_daily d
      on d.org_id = c.org_id and d.date = (now() - interval '1 day')::date
    where d.org_id is null
  )
  insert into public.alert_outbox(key, payload)
  select 'rollup_freshness_missing', jsonb_build_object('org_id', m.org_id, 'date', (now()-interval '1 day')::date)
  from missing_orgs m;
end;
$$;
