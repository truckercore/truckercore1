create table if not exists public.game_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  user_id uuid not null,
  kind text not null,
  points int not null default 0,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_game_events_org_user on public.game_events(org_id, user_id, created_at desc);
alter table public.game_events enable row level security;
create policy game_events_org_rw on public.game_events
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
