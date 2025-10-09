begin;
-- CREATE TABLE/INDEX/CONSTRAINT for <module> (idempotent IF NOT EXISTS)
-- Example:
-- create table if not exists public.<module>_entities (
--   id uuid primary key default gen_random_uuid(),
--   created_at timestamptz not null default now()
-- );
commit;
