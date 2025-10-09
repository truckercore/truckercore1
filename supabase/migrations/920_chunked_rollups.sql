create or replace function public.rollup_org_metrics_daily_chunked(batch_size int default 100)
returns void language plpgsql security definer set search_path=public as $$
declare
  org_ids uuid[];
  total int;
  i int := 1;
  day date := (now() - interval '1 day')::date;
begin
  select array_agg(id) into org_ids from public.orgs;
  total := coalesce(array_length(org_ids,1), 0);
  while i <= total loop
    insert into public.org_metrics_daily(org_id, date, miles, revenue_usd)
    select p.org_id, day,
           coalesce(sum(t.total_miles),0) as miles,
           coalesce(sum(r.amount_usd),0) as revenue_usd
    from public.profiles p
    left join public.ifta_trips t on t.org_id = p.org_id and t.ended_at::date = day
    left join public.load_revenue r on r.org_id = p.org_id and r.received_at::date = day
    where p.org_id = any( org_ids[i:least(i+batch_size-1, total)] )
    group by 1,2
    on conflict (org_id, date) do nothing;

    i := i + batch_size;
  end loop;
end;
$$;
