-- 991_feature_flags.sql
create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  note text,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags(key, enabled, note)
values ('instant_pay', false, 'Guardrail off by default')
on conflict (key) do nothing;

create or replace function public.set_feature_flag(p_key text, p_enabled boolean, p_note text default null)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.feature_flags(key, enabled, note)
  values (p_key, p_enabled, p_note)
  on conflict (key) do update
    set enabled = excluded.enabled,
        note = coalesce(excluded.note, feature_flags.note),
        updated_at = now();
$$;

create or replace function public.feature_enabled(p_key text)
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(
    (select enabled from public.feature_flags where key = p_key),
    false
  );
$$;
