-- docs/supabase/download_manifests.sql
-- File manifest and hash history with anomalies and admin revocations. Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.download_manifests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  file_key text not null,
  version int not null default 1,
  sha256 text not null,
  size_bytes bigint not null,
  created_at timestamptz not null default now(),
  anomaly_flags text[] not null default '{}'::text[],
  meta jsonb not null default '{}'::jsonb
);
create unique index if not exists uq_manifest_key_ver on public.download_manifests(org_id, file_key, version);

create table if not exists public.download_hash_history (
  org_id uuid not null,
  file_key text not null,
  observed_at timestamptz not null default now(),
  sha256 text not null,
  size_bytes bigint not null,
  source text not null default 'system',
  primary key (org_id, file_key, observed_at)
);

create table if not exists public.download_revocations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  file_key text not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default now()
);

alter table public.download_manifests enable row level security;
alter table public.download_hash_history enable row level security;

-- Read-only in app scope
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS downloads_read_org ON public.download_manifests;
  CREATE POLICY downloads_read_org ON public.download_manifests
    FOR SELECT TO authenticated
    USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS downloads_hist_read_org ON public.download_hash_history;
  CREATE POLICY downloads_hist_read_org ON public.download_hash_history
    FOR SELECT TO authenticated
    USING (org_id::text = public.jwt_claim('app_org_id'));
END $$;

-- Ingest/upsert function per spec
create or replace function public.fn_upsert_manifest(
  p_org_id uuid,
  p_file_key text,
  p_sha256 text,
  p_size bigint,
  p_meta jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
as $$
declare v_latest record;
begin
  select * into v_latest
  from public.download_manifests
  where org_id = p_org_id and file_key = p_file_key
  order by version desc limit 1;

  if v_latest is null or v_latest.sha256 <> p_sha256 then
    insert into public.download_manifests(org_id, file_key, version, sha256, size_bytes, meta)
    values (p_org_id, p_file_key, coalesce(v_latest.version,0)+1, p_sha256, p_size, coalesce(p_meta,'{}'::jsonb));

    insert into public.download_hash_history(org_id, file_key, sha256, size_bytes, source)
    values (p_org_id, p_file_key, p_sha256, p_size, 'ingest');
  end if;
end $$;

revoke all on function public.fn_upsert_manifest(uuid,text,text,bigint,jsonb) from public;
grant execute on function public.fn_upsert_manifest(uuid,text,text,bigint,jsonb) to service_role;
