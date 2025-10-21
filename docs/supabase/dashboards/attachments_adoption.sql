-- Attachments adoption (% incidents with ≥1 attachment), by week
with inc as (
  select date_trunc('week', created_at) wk,
         count(*) as total,
         count(*) filter (where jsonb_array_length(coalesce(attachments,'[]'::jsonb)) >= 1) as with_attach
  from public.safety_incidents
  group by 1
)
select wk,
       total,
       with_attach,
       round(100.0 * with_attach / nullif(total,0), 2) as adoption_pct
from inc
order by wk;