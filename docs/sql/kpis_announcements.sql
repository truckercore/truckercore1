-- docs/sql/kpis_announcements.sql
create or replace function public.eval_audience(p_sql text)
returns table(id uuid)
language plpgsql
security definer
set search_path=public
as $$
begin
  return query execute format('select id from public.users where %s', p_sql);
end $$;

create or replace view public.v_announcement_delivery as
select a.id,
       a.slug,
       a.sent_at,
       a.target_filter_sql,
       delivered.count_delivered,
       intended.count_intended,
       1.0 * delivered.count_delivered / nullif(intended.count_intended, 0) as coverage_ratio
from public.announcements a
left join lateral (
  select count(*) as count_delivered
  from public.announcement_receipts r
  where r.announcement_id = a.id
) delivered on true
left join lateral (
  select count(*) as count_intended
  from public.users u
  where u.id in (select id from public.eval_audience(a.target_filter_sql))
) intended on true;
