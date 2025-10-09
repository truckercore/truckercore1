begin;

-- Audience targeting rules for announcements
create table if not exists feature_audience_rules (
  id bigserial primary key,
  audience text not null check (audience in ('driver','owner_op','fleet','broker')),
  min_app_version text,
  region_code text,
  starts_at timestamptz default now(),
  ends_at timestamptz
);

commit;
