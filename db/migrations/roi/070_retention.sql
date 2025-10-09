begin;

create table if not exists roi_events_archive (like ai_roi_events including all);

create or replace function roi_retention_job()
returns void language plpgsql security definer as $$
begin
  insert into roi_events_archive
  select * from ai_roi_events
  where created_at < now() - interval '18 months';

  delete from ai_roi_events
  where created_at < now() - interval '18 months';
end; $$;

commit;
