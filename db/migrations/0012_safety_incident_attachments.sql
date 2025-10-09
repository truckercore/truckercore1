-- 0012_safety_incident_attachments.sql
-- Adds jsonb attachments column (default []) and idempotent helper

begin;

-- Add column if missing
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'safety_incidents'
      and column_name = 'attachments'
  ) then
    alter table public.safety_incidents
      add column attachments jsonb not null default '[]'::jsonb;
  end if;
end
$$;

-- Optional: check constraint to ensure it's an array
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'safety_incidents_attachments_is_array'
  ) then
    alter table public.safety_incidents
      add constraint safety_incidents_attachments_is_array
      check (jsonb_typeof(attachments) = 'array');
  end if;
end
$$;

-- Optional: GIN index for querying attachment metadata
create index if not exists idx_safety_incidents_attachments_gin
  on public.safety_incidents using gin (attachments jsonb_path_ops);

-- COMMENT to document shape for UIs/introspection
comment on column public.safety_incidents.attachments
  is 'JSONB array of attachments {url text, type text, metadata jsonb}';

-- Optional: stricter CHECK to enforce array-of-objects with required keys
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'safety_inc_attachments_shape'
      and conrelid = 'public.safety_incidents'::regclass
  ) then
    alter table public.safety_incidents
      add constraint safety_inc_attachments_shape check (
        jsonb_typeof(attachments) = 'array'
        and (
          select bool_and(
            jsonb_typeof(elem) = 'object'
            and (elem ? 'url') and jsonb_typeof(elem->'url') = 'string'
            and (elem ? 'type') and jsonb_typeof(elem->'type') = 'string'
            and (not (elem ? 'metadata') or jsonb_typeof(elem->'metadata') = 'object')
          )
          from jsonb_array_elements(attachments) as elem
        )
      );
  end if;
end $$;

-- Optional: deprecation comments for legacy columns (only if they exist)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'safety_incidents' and column_name = 'file_url'
  ) then
    execute $$comment on column public.safety_incidents.file_url is 'DEPRECATED: use attachments JSONB array';$$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'safety_incidents' and column_name = 'photo'
  ) then
    execute $$comment on column public.safety_incidents.photo is 'DEPRECATED: use attachments JSONB array';$$;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'safety_incidents' and column_name = 'image_url'
  ) then
    execute $$comment on column public.safety_incidents.image_url is 'DEPRECATED: use attachments JSONB array';$$;
  end if;
end $$;

commit;
