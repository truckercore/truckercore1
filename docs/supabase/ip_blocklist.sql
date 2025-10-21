-- docs/supabase/ip_blocklist.sql
-- IP blocklist with exponential backoff and appeal flow. Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.ip_blocklist (
  ip inet primary key,
  reason text not null,
  hits int not null default 1,
  blocked_until timestamptz not null,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.ip_appeals (
  id uuid primary key default gen_random_uuid(),
  ip inet not null,
  org_id uuid null,
  contact text not null,
  message text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz null,
  reviewed_by uuid null
);

-- Optional view to determine if blocked now
create or replace view public.v_ip_blocked_now as
select ip, reason, blocked_until, last_seen
from public.ip_blocklist
where blocked_until > now();

-- RLS (read-only within org if you store org-scoped IPs; skip for global list)
alter table public.ip_appeals enable row level security;
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS ip_appeals_read_org ON public.ip_appeals;
  CREATE POLICY ip_appeals_read_org ON public.ip_appeals
  FOR SELECT TO authenticated
  USING (org_id is null OR org_id::text = public.jwt_claim('app_org_id'));

  DROP POLICY IF EXISTS ip_appeals_write_self ON public.ip_appeals;
  CREATE POLICY ip_appeals_write_self ON public.ip_appeals
  FOR INSERT TO authenticated
  WITH CHECK (org_id is null OR org_id::text = public.jwt_claim('app_org_id'));

  DROP POLICY IF EXISTS ip_appeals_update_admin ON public.ip_appeals;
  CREATE POLICY ip_appeals_update_admin ON public.ip_appeals
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
END $$;
