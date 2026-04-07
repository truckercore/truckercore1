-- Admin diff view: latest change per feature key for presentations
-- Safe to re-run

create or replace view public.v_feature_last_changes as
select key,
       (new->>'headline') as headline,
       actor,
       at
from (
  select *, row_number() over (partition by key order by at desc) as rn
  from public.feature_audit
  where table_name = 'feature_presentations' and op = 'UPDATE'
) t
where rn = 1;
