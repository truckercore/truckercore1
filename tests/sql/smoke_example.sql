-- tests/sql/smoke_example.sql
-- Post-migration smoke tests for example_entities (run with psql -v ON_ERROR_STOP=1 -f this_file)

-- 1) Table exists
select to_regclass('public.example_entities') as exists_table;

-- 2) Constraints: good row should insert
insert into public.example_entities (org_id, name) values ('11111111-1111-1111-1111-111111111111','Alpha') returning id;

-- 3) Constraints: bad row (short name) should fail inside a DO block and be caught
DO $$
BEGIN
  BEGIN
    INSERT INTO public.example_entities (org_id, name) VALUES ('11111111-1111-1111-1111-111111111111','x');
    RAISE EXCEPTION 'Constraint not enforced';
  EXCEPTION WHEN check_violation THEN
    -- ok
    NULL;
  END;
END$$;

-- 4) Index check (org_id + status)
explain analyze
select * from public.example_entities
where org_id='11111111-1111-1111-1111-111111111111' and status='active' limit 1;
