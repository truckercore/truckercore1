alter table public.function_audit_log
  add column if not exists actor_ip text,
  add column if not exists user_agent text;
