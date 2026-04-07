-- Migration: Enterprise RBAC + audit scaffolding (guarded)
-- Date: 2025-09-27

-- Map IdP groups to app roles
create table if not exists public.idp_group_roles (
  id bigserial primary key,
  idp_name text not null,
  group_name text not null,
  app_role text not null
);

-- Org-role membership table
create table if not exists public.org_user_roles (
  org_id uuid not null,
  user_id uuid not null,
  app_role text not null,
  primary key (org_id, user_id)
);

-- Break-glass admin table
create table if not exists public.break_glass_admins (
  user_id uuid primary key,
  expires_at timestamptz not null
);

-- Security-sensitive audit trail (append-only)
create table if not exists public.audit_security_actions (
  id bigserial primary key,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid,
  org_id uuid,
  action text not null,
  details jsonb not null,
  sig bytea,
  immutable boolean not null default true
);

create or replace function public.log_security_action(p_actor uuid, p_org uuid, p_action text, p_details jsonb)
returns void language sql as $$
  insert into public.audit_security_actions (actor_user_id, org_id, action, details) values (p_actor, p_org, p_action, p_details);
$$;

-- RLS helper
create or replace function public.require_role(p_org uuid, p_user uuid, p_role text)
returns boolean language sql as $$
  select exists (
    select 1 from public.org_user_roles r
    where r.org_id = p_org and r.user_id = p_user and r.app_role = p_role
  ) or exists (
    select 1 from public.break_glass_admins b where b.user_id = p_user and b.expires_at > now()
  );
$$;

-- Example: enforce per-resource RBAC on loads table (guarded)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='loads') THEN
    EXECUTE 'alter table public.loads enable row level security';
    -- Policies guarded by existence
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='loads' AND policyname='loads_org_access') THEN
      EXECUTE $$create policy loads_org_access on public.loads
        using (org_id = (auth.jwt()->>'app_org_id')::uuid)
        with check (org_id = (auth.jwt()->>'app_org_id')::uuid)$$;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='loads' AND policyname='loads_dispatcher_read') THEN
      EXECUTE $$create policy loads_dispatcher_read on public.loads for select
        using (public.require_role(org_id::uuid, auth.uid(), 'dispatcher'))$$;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='loads' AND policyname='loads_finance_read') THEN
      EXECUTE $$create policy loads_finance_read on public.loads for select
        using (public.require_role(org_id::uuid, auth.uid(), 'finance'))$$;
    END IF;
  END IF;
END$$;