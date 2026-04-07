-- Pilot fixture: minimal seed data for local dev
-- Idempotent inserts guarded by table existence

-- orgs
do $$
begin
  if to_regclass('public.orgs') is not null then
    insert into public.orgs (id, name)
    values ('00000000-0000-0000-0000-000000000001', 'Pilot Org')
    on conflict (id) do nothing;
  end if;
end $$;

-- parking_state sample row
-- Note: adjust columns as per your schema; using common columns id, location_id, spaces_free, updated_at
do $$
begin
  if to_regclass('public.parking_state') is not null then
    -- try to insert a placeholder row if table has the expected columns
    begin
      insert into public.parking_state (location_id, spaces_free, updated_at)
      values ('00000000-0000-0000-0000-000000000001', 42, now());
    exception when undefined_column then
      -- skip if columns differ
      null;
    end;
  end if;
end $$;

-- safety_incidents: ensure at least one row with empty attachments
do $$
begin
  if to_regclass('public.safety_incidents') is not null then
    insert into public.safety_incidents (id, attachments)
    values (gen_random_uuid(), '[]'::jsonb);
  end if;
end $$;
