-- docs/supabase/download_security.sql
-- Download token binding (UA/IP fingerprint), logs, and anomaly view. Idempotent.

create extension if not exists pgcrypto;

-- 1) Token store for signed download links (bound to UA/IP fingerprint)
create table if not exists public.download_tokens (
  token_id uuid primary key,
  org_id uuid not null,
  status text not null default 'active' check (status in ('active','revoked','expired')),
  exp timestamptz not null,
  fp text not null,                  -- bound fingerprint (sha256 base64url)
  salt text not null,                -- full salt (base64url)
  fallback_used boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_download_tokens_org_exp on public.download_tokens (org_id, exp desc);

-- 2) Simple download logs for anomaly detection (HTTP code distribution)
create table if not exists public.download_logs (
  id bigserial primary key,
  org_id uuid not null,
  code int not null,                 -- HTTP status code
  path text not null,
  ts timestamptz not null default now()
);
create index if not exists idx_dl_org_time on public.download_logs (org_id, ts desc);

-- 3) Weekly anomaly view: 2xx / 4xx / 5xx and error rate
create or replace view public.v_download_anomalies_week as
select
  org_id,
  date_trunc('week', ts) as wk,
  count(*) filter (where code between 200 and 299) as ok,
  count(*) filter (where code between 400 and 499) as c4xx,
  count(*) filter (where code between 500 and 599) as c5xx,
  case when count(*) = 0 then 0 else (count(*) filter (where code between 400 and 599))::decimal / count(*) end as err_rate
from public.download_logs
where ts >= now() - interval '8 weeks'
group by 1,2;

-- 4) RLS: allow authenticated to read logs for their org (optional). Writes via service role only.
alter table public.download_tokens enable row level security;
alter table public.download_logs enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS download_logs_read_org ON public.download_logs;
  CREATE POLICY download_logs_read_org ON public.download_logs
  FOR SELECT TO authenticated
  USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- token rows are service-managed; do not grant writes to clients
revoke insert, update, delete on public.download_tokens from authenticated;
revoke insert, update, delete on public.download_logs from authenticated;

-- 5) Touch trigger for updated_at
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_download_tokens_touch') THEN
    CREATE TRIGGER tr_download_tokens_touch BEFORE UPDATE ON public.download_tokens
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
  END IF;
END $$;