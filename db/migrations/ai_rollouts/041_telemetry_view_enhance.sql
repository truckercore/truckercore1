begin;

create or replace view ai_promo_health as
with e as (
  select
    date_trunc('hour', created_at) as bucket,
    count(*)                                                     as n_total,
    count(*) filter (where (snapshot->>'status')='canary' or (snapshot->>'strategy')='canary') as n_canary,
    percentile_cont(0.95) within group (order by ((snapshot->>'t_ms')::int))                     as p95_ms
  from ai_promo_audit
  where created_at > now() - interval '48 hours'
  group by 1
)
select * from e order by bucket desc;

grant select on ai_promo_health to anon, authenticated;

commit;
