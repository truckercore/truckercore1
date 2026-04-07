-- docs/supabase/poi_import.sql
-- POI self-serve import staging and upsert RPC. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Staging table (org-scoped with RLS)
create table if not exists public.poi_import_staging (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null,
  kind text not null check (kind in ('truck_stop','rest_area','weigh_station','wash','repair','fuel')),
  lat double precision not null,
  lng double precision not null,
  metadata jsonb not null default '{}'::jsonb,
  uploaded_by uuid not null,
  uploaded_at timestamptz not null default now()
);

alter table public.poi_import_staging enable row level security;

-- JWT claim helper (shared pattern)
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists poi_import_rw on public.poi_import_staging
for all to authenticated
using (org_id::text = public.jwt_claim('app_org_id'))
with check (org_id::text = public.jwt_claim('app_org_id'));

-- 2) Upsert RPC from staging -> pois
-- Note: this assumes a target table public.pois exists with columns (id uuid pk, org_id uuid, name text, kind text, lat double precision, lng double precision, metadata jsonb)
-- If your schema differs, adjust the INSERT column list accordingly.
create or replace function public.fn_pois_upsert_from_staging(p_org_id uuid)
returns table(inserted int, updated int)
language plpgsql
security definer
as $$
declare v_ins int := 0; v_upd int := 0;
begin
  -- Simple implementation: insert-all for the org; de-duplication rules can be added later
  insert into public.pois(id, name, kind, lat, lng, org_id, metadata)
  select gen_random_uuid(), s.name, s.kind, s.lat, s.lng, s.org_id, coalesce(s.metadata,'{}'::jsonb)
  from public.poi_import_staging s where s.org_id = p_org_id;
  get diagnostics v_ins = row_count;

  delete from public.poi_import_staging where org_id = p_org_id;
  return query select v_ins, v_upd;
end $$;

grant execute on function public.fn_pois_upsert_from_staging(uuid) to authenticated, service_role;
