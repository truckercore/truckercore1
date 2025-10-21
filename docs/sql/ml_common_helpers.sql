-- Common helpers: claims + RLS patterns
create or replace function app_org_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

create or replace function app_role() returns text
language sql stable as $$
  select auth.jwt()->>'app_role'
$$;

create or replace function enforce_org_id() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.org_id is distinct from app_org_id() then
    raise exception 'org_id mismatch';
  end if;
  return new;
end $$;
