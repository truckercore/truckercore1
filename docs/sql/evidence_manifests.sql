-- docs/sql/evidence_manifests.sql
-- Optional registry for SOC 2 evidence manifest hashes (WORM bucket uploads managed externally)

create table if not exists public.evidence_manifests(
  id uuid primary key default gen_random_uuid(),
  period text not null,                 -- e.g., '2025-W37'
  path text not null,                   -- bucket/prefix
  sha256_manifest text not null,        -- hex of manifest.json
  created_at timestamptz not null default now()
);
