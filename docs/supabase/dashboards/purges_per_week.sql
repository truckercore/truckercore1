-- Purge deletes per week (choose the variant that matches your schema)
-- If you track purges in a table
select date_trunc('week', purged_at) as week,
       table_name,
       count(*) as rows_purged
from public.purge_audit
group by 1,2
order by 1,2;

-- If you only have a deleted_at column on safety_incidents
-- select date_trunc('week', deleted_at) as week,
--        'safety_incidents' as table_name,
--        count(*) as rows_purged
-- from public.safety_incidents
-- where deleted_at is not null
-- group by 1
-- order by 1;