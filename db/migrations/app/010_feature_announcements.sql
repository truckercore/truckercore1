begin;

create table if not exists public.feature_announcements (
  id uuid primary key default gen_random_uuid(),
  audience text not null check (audience in ('driver','owner_op','fleet','broker')),
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.feature_announcements enable row level security;

create policy if not exists fa_read_public on public.feature_announcements
for select to authenticated
using (true);

commit;
