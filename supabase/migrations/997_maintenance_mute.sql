create table if not exists public.maintenance_windows (
  id bigserial primary key,
  starts_at timestamptz not null,
  ends_at   timestamptz not null,
  note text
);

create or replace function public.alerts_muted()
returns boolean language sql stable as $$
  select exists(
    select 1 from public.maintenance_windows
    where now() between starts_at and ends_at
  );
$$;

create or replace function public.enqueue_alert_if_not_muted(p_key text, p_payload jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.alerts_muted() then
    return;
  end if;
  perform public.enqueue_alert(p_key, p_payload);
end; $$;