create or replace view v_shipper_tenders as
select t.id, t.status, t.created_at,
       (t.pickup_address->>'line1') as pickup, (t.dropoff_address->>'line1') as dropoff,
       count(q.*) filter (where q.status='proposed') as quotes_proposed,
       count(q.*) filter (where q.status='accepted') as quotes_accepted,
       min(q.price_cents) as lowest_quote_cents
from tenders t
left join tender_quotes q on q.tender_id = t.id
group by t.id;

create or replace view v_3pl_open_loads as
select t.id, t.status, t.created_at, t.commodity, t.weight_kg,
       (t.pickup_address->>'line1') as pickup, (t.dropoff_address->>'line1') as dropoff
from tenders t
where t.status in ('open','quoted');
