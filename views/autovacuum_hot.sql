select relname, n_live_tup, n_dead_tup, last_autovacuum
from pg_stat_all_tables
where schemaname='public'
order by n_dead_tup desc;
