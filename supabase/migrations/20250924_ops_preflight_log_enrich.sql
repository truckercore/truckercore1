-- 20250924_ops_preflight_log_enrich.sql
-- Enrich ops_preflight_log with actor, commit_sha, env columns (idempotent)

alter table if exists public.ops_preflight_log
  add column if not exists actor text,
  add column if not exists commit_sha text,
  add column if not exists env text;
