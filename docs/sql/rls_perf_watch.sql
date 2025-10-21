create or replace view public.v_rls_hot as
select queryid, calls, mean_time, rows, query
from pg_stat_statements
where query ~* 'from .* (tenders|invoices|expenses)'
order by mean_time desc
limit 20;
