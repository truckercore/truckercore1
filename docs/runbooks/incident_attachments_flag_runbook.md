# Incident Attachments: Tagging, Flagging, Deploy, Soak, Rollback

This runbook accompanies the attachments work and provides concrete steps/scripts.

## Tag & DB-first changelog
- Generate a tag and short DB changelog:
  - npm run release:tag -- v0.x.y
  - This creates CHANGELOG_DB_v0.x.y.md, commits, tags, and pushes your branch and tags.

## Feature flag (read guard)
- GUC key: app.incident_attachments_enabled
- Default: false
- Activate for your current session:
  - select set_config('app.incident_attachments_enabled','true', false);
- Guarded view example (applied via docs/supabase/incident_attachments_flag.sql):
  - create or replace view public.v_safety_incidents as
    select * from public.safety_incidents
    where coalesce(current_setting('app.incident_attachments_enabled', true), 'false') = 'true';

## Staging soak helpers
- Retention no-op probe (uses existing purge function):
  - begin; select public.fn_purge_old_attachments(0); rollback;
- Small cohort run: scope your purge/background job to a tiny org/location in staging first.

## Production deploy (idempotent)
- Script: scripts/release/prod_deploy_si_attachments.sh
- Requires: DATABASE_URL
- Steps baked in:
  1) Guarded create/ensure of attachments jsonb column and COMMENT
  2) Ensure default + CHECK (array) and GIN index (jsonb_path_ops)
  3) Smoke non-array/null count
  4) TX good insert (rolled back)
  5) EXPLAIN ANALYZE for @> predicate

## Activation & monitoring
- Activate reads: select set_config('app.incident_attachments_enabled','true', false);
- Watch for:
  - Trigger blocks (if you enable temporary write-block): look for errors in logs
  - Schema drift: non-array/null rows should be 0
    - select count(*) from public.safety_incidents where attachments is null or jsonb_typeof(attachments) <> 'array';
  - Index health (cache stats):
    - select schemaname, relname, idx_blks_read, idx_blks_hit from pg_statio_all_indexes where indexrelname = 'idx_safety_incidents_attachments_gin';

## Rollback
- If problems arise during soak:
  - Enable temporary write block (see docs/supabase/si_attachments_triggers.sql) to stop new writes
  - Disable read flag: select set_config('app.incident_attachments_enabled','false', false);
  - Restore from snapshot if corruption is detected; otherwise keep schema and fix upstream
  - Drop write-block trigger once stable

## Hygiene
- VACUUM ANALYZE public.safety_incidents weekly if needed
- Keep only a single GIN index on attachments
- Ensure CI continues to assert good/bad inserts and GIN path ops checks
