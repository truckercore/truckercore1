begin;

-- Store report metadata (idempotent)
create table if not exists public.exec_reports (
  org_id uuid not null,
  period_ym text not null, -- 'YYYY-MM'
  url text,
  checksum text,
  created_at timestamptz not null default now(),
  primary key (org_id, period_ym)
);

alter table public.exec_reports enable row level security;

-- Org-scoped read policy for authenticated users
create policy if not exists exec_reports_read_org on public.exec_reports
for select to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);

commit;
