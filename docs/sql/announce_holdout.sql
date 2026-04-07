-- docs/sql/announce_holdout.sql
alter table if exists public.announcements
  add column if not exists holdout_pct int default 5 check (holdout_pct >= 0 and holdout_pct <= 50);

create or replace view public.v_announcement_quality as
select a.id, a.slug, a.sent_at,
  (select count(*) from public.announcement_receipts r where r.announcement_id=a.id and r.delivered_at is not null) as delivered,
  (select count(*) from public.announcement_receipts r where r.announcement_id=a.id and r.failed_at    is not null) as failed,
  (select count(*) from public.eval_audience(a.target_filter_sql)) as intended,
  round(100.0 * (select count(*) from public.announcement_receipts r where r.announcement_id=a.id and r.delivered_at is not null)
        / nullif((select count(*) from public.eval_audience(a.target_filter_sql)),0), 2) as delivery_rate_pct,
  a.holdout_pct
from public.announcements a
order by a.sent_at desc;
