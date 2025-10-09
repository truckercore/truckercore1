create table if not exists public.facility_reviews (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  facility_name text not null,
  rating int not null check (rating between 1 and 5),
  comments text,
  reported_by uuid not null,
  reported_at timestamptz not null default now()
);
create index if not exists idx_facility_reviews_org_time on public.facility_reviews(org_id, reported_at desc);
alter table public.facility_reviews enable row level security;
create policy facility_reviews_org_rw on public.facility_reviews
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
