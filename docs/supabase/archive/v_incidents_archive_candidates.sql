-- View: incidents ready for archival to cold storage
create or replace view public.v_incidents_archive_candidates as
select id, created_at, resolved_at, deleted_at, attachments
from public.safety_incidents
where resolved_at is not null
  and resolved_at < now() - interval '180 days'
  and (deleted_at is null or deleted_at < now() - interval '30 days');