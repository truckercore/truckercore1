create or replace view public.v_rls_lint as
select p.schemaname, p.tablename, p.policyname, p.cmd,
       (p.qual is null or p.qual ~* '^\s*true\s*$')  as is_true_using,
       (p.with_check is null or p.with_check ~* '^\s*true\s*$') as is_true_check
from pg_policies p
where schemaname='public';

create or replace view public.v_rls_insert_check_gaps as
select tablename
from pg_policies
where schemaname='public'
group by tablename
having bool_or(cmd='insert') and not bool_or(cmd='insert' and with_check is not null);
