-- Backfill requests ledger (v1)
-- Optional table used by backfill_enqueue EF for visibility

create table if not exists public.backfill_requests (
  id bigserial primary key,
  org_id uuid not null,
  domain text not null check (domain in ('hos','inspections','loads_kpis','ai_audit')),
  since timestamptz,
  until timestamptz,
  requested_by text,
  status text not null default 'queued' check (status in ('queued','running','done','error','canceled')),
  job_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_backfill_org_time on public.backfill_requests(org_id, created_at desc);
