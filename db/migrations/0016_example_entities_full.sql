-- 0016_example_entities_full.sql
-- Purpose: Bring example_entities to the required spec (shape, constraints, RLS, indexes, audit, retention helper stubs)
-- Notes: Idempotent and safe to re-run. Does not drop previously added optional columns (e.g., status) or uniques.

begin;

-- Ensure core table exists with base columns
create table if not exists public.example_entities (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure updated_at column exists (for older versions)
alter table public.example_entities
  add column if not exists updated_at timestamptz not null default now();

-- Relax/ensure name length constraint to [2,120]
-- Drop the old implicit constraint if present, then add a named one
DO $$
BEGIN
  IF exists (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.example_entities'::regclass
      AND conname = 'example_entities_name_check'
  ) THEN
    ALTER TABLE public.example_entities DROP CONSTRAINT example_entities_name_check;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.example_entities'::regclass
      AND conname = 'chk_example_entities_name_len'
  ) THEN
    ALTER TABLE public.example_entities
      ADD CONSTRAINT chk_example_entities_name_len CHECK (length(name) BETWEEN 2 AND 120);
  END IF;
END $$;

-- meta.tier validation (only allow when present)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.example_entities'::regclass
      AND conname = 'meta_tier_valid'
  ) THEN
    ALTER TABLE public.example_entities
      ADD CONSTRAINT meta_tier_valid CHECK (
        (meta ? 'tier') IS FALSE OR (meta->>'tier') IN ('gold','silver','bronze')
      );
  END IF;
END $$;

-- Indexes per spec
create index if not exists idx_example_entities_org on public.example_entities(org_id);
create index if not exists idx_example_entities_meta_gin on public.example_entities using gin (meta jsonb_path_ops);

-- RLS: enable and policies (idempotent)
alter table public.example_entities enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='example_entities' AND policyname='example_entities_select_org'
  ) THEN
    CREATE POLICY example_entities_select_org ON public.example_entities
    FOR SELECT TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='example_entities' AND policyname='example_entities_ins_org'
  ) THEN
    CREATE POLICY example_entities_ins_org ON public.example_entities
    FOR INSERT TO authenticated
    WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='example_entities' AND policyname='example_entities_upd_org'
  ) THEN
    CREATE POLICY example_entities_upd_org ON public.example_entities
    FOR UPDATE TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
    WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- updated_at touch trigger
create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_touch_example_entities on public.example_entities;
create trigger trg_touch_example_entities
before update on public.example_entities
for each row execute function public.tg_touch_updated_at();

-- Audit table and trigger
create table if not exists public.example_entities_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  entity_id uuid not null,
  action text not null check (action in ('insert','update','delete')),
  diff jsonb,
  actor uuid,
  created_at timestamptz not null default now()
);

create or replace function public.tg_example_entities_audit()
returns trigger language plpgsql as $$
declare v_action text; v_diff jsonb;
begin
  if tg_op = 'INSERT' then v_action := 'insert'; v_diff := to_jsonb(new);
  elsif tg_op = 'UPDATE' then v_action := 'update'; v_diff := jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new));
  else v_action := 'delete'; v_diff := to_jsonb(old);
  end if;
  insert into public.example_entities_audit(org_id, entity_id, action, diff)
  values (coalesce(new.org_id, old.org_id), coalesce(new.id, old.id), v_action, v_diff);
  return null;
end $$;

drop trigger if exists trg_audit_example_entities on public.example_entities;
create trigger trg_audit_example_entities
after insert or update or delete on public.example_entities
for each row execute function public.tg_example_entities_audit();

-- Comments
comment on table public.example_entities is 'Example, org-scoped; meta.tier in {gold,silver,bronze}.';
comment on index idx_example_entities_meta_gin is 'GIN index for meta @> queries on jsonb.';

commit;
