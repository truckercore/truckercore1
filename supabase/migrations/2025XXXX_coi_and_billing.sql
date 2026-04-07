-- 1) COI document registry
create table if not exists public.coi_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  file_key text not null,
  mime text not null,
  size_bytes bigint not null check (size_bytes >= 0 and size_bytes <= 20*1024*1024),
  uploaded_at timestamptz default now(),
  verified boolean default false,
  notes text
);

create index if not exists coi_org_idx on public.coi_documents(org_id, uploaded_at desc);
create index if not exists coi_user_idx on public.coi_documents(user_id, uploaded_at desc);

alter table public.coi_documents enable row level security;

-- Replace claim key if your JWT uses app_org_id
create policy if not exists coi_select_org
  on public.coi_documents for select
  using (
    org_id = coalesce(
      nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'app_org_id',
      current_setting('request.jwt.claims', true)::jsonb->>'org_id'
    )::uuid
  );

create policy if not exists coi_insert_self
  on public.coi_documents for insert
  with check (
    user_id = auth.uid()
    and org_id = coalesce(
      nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'app_org_id',
      current_setting('request.jwt.claims', true)::jsonb->>'org_id'
    )::uuid
  );

create policy if not exists coi_update_self_meta
  on public.coi_documents for update
  using (
    user_id = auth.uid()
    and org_id = coalesce(
      nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'app_org_id',
      current_setting('request.jwt.claims', true)::jsonb->>'org_id'
    )::uuid
  )
  with check (user_id = auth.uid());

create or replace function public.coi_mark_verified(p_id uuid, p_verified boolean, p_notes text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.coi_documents
  set verified = p_verified, notes = p_notes
  where id = p_id;
end $$;

revoke all on function public.coi_mark_verified(uuid,boolean,text) from public;
grant execute on function public.coi_mark_verified(uuid,boolean,text) to service_role;

-- 2) Storage bucket 'coi' (private)
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'coi') then
    insert into storage.buckets (id, name, public) values ('coi','coi', false);
  end if;
end$$;

-- storage.objects RLS for 'coi'
create policy if not exists storage_coi_read_org on storage.objects
  for select using (
    bucket_id = 'coi'
    and coalesce(metadata->>'org_id','') = coalesce(
      nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'app_org_id',
      current_setting('request.jwt.claims', true)::jsonb->>'org_id'
    )
  );

create policy if not exists storage_coi_user_put on storage.objects
  for insert with check (
    bucket_id = 'coi'
    and coalesce(metadata->>'user_id','') = auth.uid()::text
    and coalesce(metadata->>'org_id','') = coalesce(
      nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'app_org_id',
      current_setting('request.jwt.claims', true)::jsonb->>'org_id'
    )
  );

-- 3) Profiles entitlements
alter table if exists public.profiles
  add column if not exists app_tier text default 'basic',
  add column if not exists app_is_premium boolean default false;

-- 4) Billing bookkeeping
create table if not exists public.billing_customers (
  org_id uuid primary key,
  stripe_customer_id text unique not null,
  created_at timestamptz default now()
);

create table if not exists public.billing_subscriptions (
  org_id uuid primary key,
  stripe_subscription_id text unique not null,
  tier text not null check (tier in ('basic','standard','premium','enterprise')),
  status text not null,
  current_period_end timestamptz,
  updated_at timestamptz default now()
);

-- 5) Optional telemetry table
create table if not exists public.event_log (
  id bigserial primary key,
  org_id uuid null,
  user_id uuid null,
  name text not null,
  props jsonb not null default '{}',
  created_at timestamptz default now()
);
alter table public.event_log enable row level security;
create policy if not exists event_self_read on public.event_log for select using (user_id = auth.uid());
create policy if not exists event_insert_self on public.event_log for insert with check (user_id = auth.uid());