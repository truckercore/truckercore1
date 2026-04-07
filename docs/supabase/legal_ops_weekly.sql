-- docs/supabase/legal_ops_weekly.sql
-- Weekly Legal Ops summary view. Idempotent.
-- Adjust source table/column names as needed to match your deployment.

create or replace view public.legal_ops_weekly as
with w as (
  select *
  from legal_reviews -- expected columns: id, org_id, status ('new','approved','rejected'), created_at, decided_at, blocker text
  where created_at >= date_trunc('week', now()) - interval '7 days'
),
agg as (
  select
    org_id,
    count(*) filter (where status = 'new') as new_reviews,
    count(*) filter (where status = 'approved') as approvals,
    count(*) filter (where status = 'rejected') as rejections,
    round(avg(extract(epoch from (decided_at - created_at)) / 3600.0)::numeric, 2) as avg_turnaround_hours,
    count(*) filter (where status = 'new' and now() - created_at > interval '7 days') as overdue_count
  from w
  group by org_id
),
blockers as (
  select org_id, blocker, count(*) as cnt,
         row_number() over (partition by org_id order by count(*) desc) as rn
  from w
  where blocker is not null
  group by org_id, blocker
)
select
  a.org_id,
  a.new_reviews,
  a.approvals,
  a.rejections,
  a.avg_turnaround_hours,
  a.overdue_count,
  jsonb_agg(jsonb_build_object('blocker', b.blocker, 'count', b.cnt) order by b.cnt desc) filter (where b.rn <= 5) as top_blockers
from agg a
left join blockers b using (org_id)
group by a.org_id, a.new_reviews, a.approvals, a.rejections, a.avg_turnaround_hours, a.overdue_count;
