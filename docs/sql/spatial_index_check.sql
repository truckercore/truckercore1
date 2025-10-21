with geo as (
  select n.nspname as schema, c.relname as tbl, a.attname as col
  from pg_attribute a
  join pg_class c on c.oid=a.attrelid
  join pg_namespace n on n.oid=c.relnamespace
  join pg_type t on t.oid=a.atttypid
  where t.typname in ('geometry','geography') and a.attnum>0 and not a.attisdropped
),
idx as (
  select n.nspname as schema, c.relname as tbl, i.indexrelid::regclass::text as idxname, pg_get_indexdef(i.indexrelid) def
  from pg_index i
  join pg_class c on c.oid=i.indrelid
  join pg_namespace n on n.oid=c.relnamespace
)
select g.*, 'MISSING_INDEX' as hint
from geo g
left join idx on idx.schema=g.schema and idx.tbl=g.tbl and idx.def ilike '%'||g.col||'%'
where idx.idxname is null;
