-- docs/supabase/link_metrics.sql
-- Org-scoped metrics for signed link issuance vs. downloads. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Tables
create table if not exists public.link_issued_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  link_id uuid not null,
  file_key text not null,
  issued_at timestamptz not null default now()
);
create index if not exists idx_link_issued_org_time on public.link_issued_events (org_id, issued_at desc);

create table if not exists public.link_download_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  link_id uuid not null,
  file_key text not null,
  downloaded_at timestamptz not null default now()
);
create index if not exists idx_link_download_org_time on public.link_download_events (org_id, downloaded_at desc);

-- 2) RLS (read-only by org)
alter table public.link_issued_events enable row level security;
alter table public.link_download_events enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS link_issued_read_org ON public.link_issued_events;
  CREATE POLICY link_issued_read_org ON public.link_issued_events
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS link_download_read_org ON public.link_download_events;
  CREATE POLICY link_download_read_org ON public.link_download_events
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- 3) Weekly org report view (issue vs. downloads within the same week window)
create or replace view public.v_link_issue_vs_download_week as
select
  i.org_id,
  date_trunc('week', i.issued_at) as week,
  count(*) as issued_count,
  coalesce((
    select count(*) from public.link_download_events d
    where d.org_id = i.org_id and d.link_id = i.link_id
      and d.downloaded_at >= date_trunc('week', i.issued_at)
      and d.downloaded_at < date_trunc('week', i.issued_at) + interval '7 days'
  ), 0) as downloads_for_issued
from public.link_issued_events i
where i.issued_at >= now() - interval '90 days'
group by 1,2;