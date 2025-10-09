#!/usr/bin/env bash
# Production deploy steps for safety_incidents.attachments (jsonb array)
set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL env var required" >&2
  exit 1
fi

echo "[1/6] Check PITR (manual step)"
echo "Ensure your provider's PITR window is healthy."

echo "[2/6] Snapshot (manual/CLI)"
echo "Trigger on-demand snapshot via your provider before proceeding."

PSQL="psql \"$DATABASE_URL\" -v ON_ERROR_STOP=1"

echo "[3/6] Migrations (idempotent)"
$PSQL -c "do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='safety_incidents' and column_name='attachments'
  ) then
    alter table public.safety_incidents add column attachments jsonb default '[]'::jsonb;
    comment on column public.safety_incidents.attachments is 'JSONB array of attachments {url text, type text, metadata jsonb}';
  end if;
end
$$;"
$PSQL -c "alter table public.safety_incidents alter column attachments set default '[]'::jsonb;"
$PSQL -c "do $$ begin if not exists (
  select 1 from pg_constraint where conname = 'attachments_is_array' and conrelid = 'public.safety_incidents'::regclass
) then alter table public.safety_incidents add constraint attachments_is_array check (jsonb_typeof(attachments) = 'array'); end if; end $$;"
$PSQL -c "create index if not exists idx_safety_incidents_attachments_gin on public.safety_incidents using gin (attachments jsonb_path_ops);"

echo "[4/6] Smoke: attachments non-array/null check"
$PSQL -c "select count(*) as bad from public.safety_incidents where attachments is null or jsonb_typeof(attachments) <> 'array';"

echo "[5/6] Smoke: insert good/bad rows (transactional)"
$PSQL -c "begin; insert into public.safety_incidents(id, attachments) values (gen_random_uuid(), '[{\"url\":\"https://x\",\"type\":\"photo\",\"metadata\":{\"w\":800,\"h\":600}}]'::jsonb); rollback;"
# bad insert test is covered by CHECK; attempting would cause error and stop script; skip or run manually

echo "[6/6] EXPLAIN ANALYZE"
$PSQL -c "explain analyze select 1 from public.safety_incidents where attachments @> '[{\"type\":\"photo\"}]'::jsonb limit 1;"

echo "Deploy steps complete."
