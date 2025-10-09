begin;

create table if not exists fleet_discounts (
  id uuid primary key default gen_random_uuid(),
  fleet_org_id uuid not null references orgs(id) on delete cascade,
  stop_org_id uuid not null references orgs(id) on delete cascade,
  fuel_cents int not null default 0,
  def_cents int not null default 0,
  start_at timestamptz not null,
  end_at timestamptz not null,
  created_at timestamptz default now()
);

create index if not exists idx_fleet_discounts_window on fleet_discounts (fleet_org_id, start_at, end_at);

alter table fleet_discounts enable row level security;
create policy fleet_discounts_fleet_read on fleet_discounts
for select using (fleet_org_id::text = coalesce((select org_id from v_claims), ''));

grant select on fleet_discounts to anon, authenticated; -- optional read-only
grant select, insert, update, delete on fleet_discounts to service_role;

comment on table fleet_discounts is 'Per-fleet negotiated cents-off for fuel/DEF by truck stop org';

commit;
