-- Flags table
create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Quarantine a function/view by flag key; clients should check flag before use
create or replace function public.quarantine_feature(p_key text, p_reason text)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.feature_flags(key, enabled) values (p_key, false)
  on conflict (key) do update set enabled = false, updated_at = now();

  insert into public.alerts_events(org_id, severity, code, payload)
  values ('00000000-0000-0000-0000-000000000000', 'critical', 'feature_quarantined',
          jsonb_build_object('key', p_key, 'reason', p_reason, 'at', now()));
end;
$$;
