create table if not exists public.discounts_promos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  vendor text not null,
  terms text,
  min_tier text not null default 'free' check (min_tier in ('free','pro','enterprise')),
  region text,
  gated boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.discounts_promos enable row level security;
-- Public-readable promos (no PII)
create policy promos_public_read on public.discounts_promos for select using (true);
