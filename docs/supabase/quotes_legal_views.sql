-- docs/supabase/quotes_legal_views.sql
-- Views for legal status on quotes and overdue reminders. Idempotent.

create or replace view public.v_quotes_with_legal as
select q.*,
       lr.status as legal_status,
       lr.id as legal_request_id
from public.quotes q
left join lateral (
  select id, status
  from public.legal_review_requests
  where quote_id = q.id
  order by created_at desc
  limit 1
) lr on true;

create or replace view public.v_quotes_legal_overdue as
select q.id as quote_id, q.org_id, lr.id as legal_request_id, lr.created_at
from public.quotes q
join public.legal_review_requests lr on lr.quote_id = q.id
where lr.status = 'pending'
  and lr.created_at <= (now() - interval '7 days');
