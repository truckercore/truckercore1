-- Instant Pay scaffolding (guarded by Edge)
create table if not exists public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  user_id uuid not null,
  amount_usd numeric(12,2) not null check (amount_usd > 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','paid')),
  proof_doc_path text,
  fee_usd numeric(12,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_by uuid null,
  reviewed_at timestamptz null,
  decision_notes text null
);
create index if not exists idx_payouts_org_time on public.payout_requests(org_id, created_at desc);
alter table public.payout_requests enable row level security;
create policy payouts_select_org on public.payout_requests for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
-- Disallow direct updates by default; only Edge function with service role updates
revoke update on public.payout_requests from authenticated;

-- Edge audit log
create table if not exists public.function_audit_log (
  id bigserial primary key,
  event_id uuid not null default gen_random_uuid(),
  fn text not null,
  actor_id uuid,
  payload_hash text,
  success boolean not null,
  error text,
  ts timestamptz not null default now()
);
