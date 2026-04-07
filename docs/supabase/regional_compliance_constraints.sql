-- Regional compliance constraints (US hazmat, EU axle weights) — stub
-- Suggested schema additions. Adjust to your naming conventions.

-- Table: regional_constraints
-- Columns:
--   region text, constraint_key text, description text, params jsonb, active boolean default true
-- PK: (region, constraint_key)

create table if not exists regional_constraints (
  region text not null,
  constraint_key text not null,
  description text not null,
  params jsonb not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (region, constraint_key)
);

-- Seed examples
insert into regional_constraints(region, constraint_key, description, params)
values
  ('US', 'hazmat_permits_required', 'Hazmat moves require org/driver hazmat endorsements and route compliance', '{"required": true}'::jsonb),
  ('EU', 'axle_weight_limits', 'Axle weights must not exceed EU limits per vehicle class', '{"max_ton_per_axle": 11.5}'::jsonb)
on conflict (region, constraint_key) do update set
  description = excluded.description,
  params = excluded.params,
  active = true;

-- Optional: a simple view to join with candidates/loads for ranker exclusion
-- create view v_regional_blocks as select ...;  -- implement per data model
