-- Webhook hardening: add last_status_code, clarify leasing via next_attempt_at

-- 1) Persist last_status_code alongside last_error on event_outbox
alter table if exists public.event_outbox
  add column if not exists last_status_code int;

comment on column public.event_outbox.last_status_code is 'HTTP status code from the last delivery attempt (if any).';

-- NOTE: Row leasing is implemented by workers atomically setting next_attempt_at in claim step
-- to now() + lease_window and incrementing delivery_attempts, selecting only rows where
-- status = 'pending' and (next_attempt_at is null or next_attempt_at <= now()). This avoids
-- double-delivery across multiple workers.

-- 2) Ensure helpful indexes exist for leasing and DLQ queries
create index if not exists idx_event_outbox_status_next_attempt on public.event_outbox (status, coalesce(next_attempt_at, created_at));

-- 3) No RLS change here; event_outbox remains service-managed via existing policy.
