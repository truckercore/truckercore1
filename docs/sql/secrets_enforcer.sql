create or replace view v_secrets_overdue as
select key, rotated_at, max_age_days
from secrets_registry
where now() - rotated_at > make_interval(days => coalesce(max_age_days,120));
