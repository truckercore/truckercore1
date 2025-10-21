-- Owner-Operator Expenses schema (Tax-Deductible Expenses)
-- Idempotent. Apply after foundation_tenancy_schema.sql so profiles/orgs/roles exist.

create table if not exists public.owner_op_expenses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  org_id uuid, -- nullable for solo owner-ops; can be set when part of a fleet
  category text not null, -- fuel_travel, maintenance_repairs, insurance, equipment_parts, licenses_permits, operational_costs, travel_lodging, office_record, miscellaneous
  description text,
  amount_cents bigint not null default 0,
  currency text not null default 'USD',
  truck_id uuid null,
  driver_user_id uuid null,
  file_url text null,
  added_at timestamptz not null default now()
);

comment on table public.owner_op_expenses is 'Owner-Operator tax-deductible expenses (per user).';
create index if not exists idx_owner_op_expenses_user on public.owner_op_expenses(owner_user_id);
create index if not exists idx_owner_op_expenses_org on public.owner_op_expenses(org_id);
create index if not exists idx_owner_op_expenses_added_at on public.owner_op_expenses(added_at);

alter table public.owner_op_expenses enable row level security;

-- RLS: owner_op users can manage their own rows; enterprise may query by org_id if owner_op fleet (future fine-tune).
-- Minimal policies:
drop policy if exists owner_expenses_select on public.owner_op_expenses;
create policy owner_expenses_select on public.owner_op_expenses
  for select using (
    owner_user_id = (select auth.uid())
    or (org_id is not null and org_id = ((select auth.jwt()) ->> 'org_id')::uuid)
  );

drop policy if exists owner_expenses_insert on public.owner_op_expenses;
create policy owner_expenses_insert on public.owner_op_expenses
  for insert with check (
    owner_user_id = (select auth.uid())
  );

drop policy if exists owner_expenses_update on public.owner_op_expenses;
create policy owner_expenses_update on public.owner_op_expenses
  for update using (
    owner_user_id = (select auth.uid())
  );

drop policy if exists owner_expenses_delete on public.owner_op_expenses;
create policy owner_expenses_delete on public.owner_op_expenses
  for delete using (
    owner_user_id = (select auth.uid())
  );

-- Optional helper: categories check (light constraint)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_owner_op_expenses_category') THEN
    ALTER TABLE public.owner_op_expenses
      ADD CONSTRAINT chk_owner_op_expenses_category
      CHECK (
        category in (
          'fuel_travel','maintenance_repairs','insurance','equipment_parts','licenses_permits',
          'operational_costs','travel_lodging','office_record','miscellaneous'
        )
      );
  END IF;
END $$;
