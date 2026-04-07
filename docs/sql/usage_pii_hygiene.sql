-- PII hygiene & minimal footprint
-- Optional: drop user_id from older rows after N days if not needed for audits

create or replace function public.usage_scrub_user_ids(days_old int default 90)
returns bigint language plpgsql as $$
declare n bigint;
begin
  update public.usage_events
  set user_id = null
  where at < now() - make_interval(days=>days_old)
    and user_id is not null;
  get diagnostics n = row_count;
  return n;
end $$;

-- Schedule monthly
