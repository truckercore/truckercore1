begin;
create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  label text,
  hashed_key text not null,               -- store SHA-256 hex of key
  scope text[] not null default '{}',     -- e.g. ['loads.read','loads.write','bids.write']
  created_at timestamptz not null default now()
);
create unique index if not exists idx_api_keys_hash on public.api_keys(hashed_key);
alter table public.api_keys enable row level security;
create policy if not exists api_keys_read_org on public.api_keys
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- writes via service role only
commit;
