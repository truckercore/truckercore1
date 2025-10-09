-- Minimal DB objects for onboarding credentials and RLS
create table if not exists public.credentials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  dot text not null,
  mc text,
  role_hint text check (role_hint in ('driver','owner_operator')),
  created_at timestamptz not null default now()
);

alter table public.credentials enable row level security;

create policy credentials_self_rw on public.credentials
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
