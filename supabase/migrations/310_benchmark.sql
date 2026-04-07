-- Benchmarks placeholder
create table if not exists public.benchmarks (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  metric text not null,
  value numeric not null,
  updated_at timestamptz not null default now()
);
alter table public.benchmarks enable row level security;
create policy benchmarks_public_read on public.benchmarks for select using (true);
