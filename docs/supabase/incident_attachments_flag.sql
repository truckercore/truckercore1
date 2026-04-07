-- Incident attachments feature flag and guarded view
-- Option A: GUC-based flag (per session/role/env)
-- Disable reads by default
select set_config('app.incident_attachments_enabled','false', false);

-- Guarded view that only exposes rows when the flag is enabled
create or replace view public.v_safety_incidents as
select *
from public.safety_incidents
where coalesce(current_setting('app.incident_attachments_enabled', true), 'false') = 'true';

-- To activate for current session (staging soak / canary):
-- select set_config('app.incident_attachments_enabled','true', false);

-- Optional: If you maintain a settings table, you can read it in app bootstrap and set the GUC.
-- update app_settings set value='true' where key='INCIDENT_ATTACHMENTS_ENABLED';

-- Staging helpers: retention no-op probe (uses existing purge function)
-- This confirms N=0 changes nothing and function runs
begin;
select public.fn_purge_old_attachments(0);
rollback;

-- Small cohort run (example using org_id filter in your app layer)
-- Run your purge job with a WHERE org_id = '00000000-0000-0000-0000-000000000000' in staging.

-- Monitoring snippets
-- Non-array/null should be 0 due to CHECKs
select count(*) as non_array_or_null
from public.safety_incidents
where attachments is null or jsonb_typeof(attachments) <> 'array';

-- Index health
select schemaname, relname, idx_blks_read, idx_blks_hit
from pg_statio_all_indexes
where indexrelname = 'idx_safety_incidents_attachments_gin';
