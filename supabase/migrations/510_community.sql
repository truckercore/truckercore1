create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  user_id uuid not null,
  message text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_community_org_time on public.community_posts(org_id, created_at desc);
alter table public.community_posts enable row level security;
create policy community_posts_org_rw on public.community_posts
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
