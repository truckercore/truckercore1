-- docs/supabase/legal_review_requests.sql
-- Legal review requests queue with org-scoped RLS. Idempotent.

create table if not exists public.legal_review_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  quote_id uuid not null,
  requester_id uuid not null,
  status text not null check (status in ('open','in_review','approved','rejected')),
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.legal_review_requests enable row level security;

create policy if not exists legal_req_rw_org on public.legal_review_requests
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
