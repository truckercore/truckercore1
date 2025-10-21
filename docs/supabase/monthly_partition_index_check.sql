-- SQL: Monthly backfill sanity for partition indexes
-- Lists each child partition of edge_request_log with its indexes.
-- Use in Supabase Studio or CLI to verify per-partition index presence.

select inhrelid::regclass as child,
       i.indexrelid::regclass as index_name
from pg_inherits
join pg_index i on inhrelid = i.indrelid
where inhparent = 'public.edge_request_log'::regclass
order by child;