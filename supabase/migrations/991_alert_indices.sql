-- 991_alert_indices.sql

create index if not exists idx_fn_audit_created_fn
  on public.function_audit_log(fn, created_at desc);

create index if not exists idx_alert_outbox_pending
  on public.alert_outbox(created_at)
  where delivered_at is null;

create index if not exists idx_alert_outbox_suppress_until
  on public.alert_outbox(suppress_until)
  where delivered_at is null;